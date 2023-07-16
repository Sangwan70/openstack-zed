#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$CONFIG_DIR/openstack"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Set up keystone for controller node
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Setting up database for keystone."
setup_database keystone "$KEYSTONE_DB_USER" "$KEYSTONE_DBPASS"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Not in install-guide:
echo "Sanity check: local auth should work."
mysql -u keystone -p"$KEYSTONE_DBPASS" keystone -e quit

echo "Sanity check: remote auth should work."
mysql -u keystone -p"$KEYSTONE_DBPASS" keystone -h controller -e quit

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install and configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing keystone."
sudo dnf install -y python3-heatclient openstack-keystone python3-openstackclient httpd httpd-core mod_ssl python3-mod_wsgi python3-oauth2client

conf=/etc/keystone/keystone.conf
echo "Editing $conf."

function get_database_url {
    local db_user=$KEYSTONE_DB_USER
    local database_host=controller

    echo "mysql+pymysql://$db_user:$KEYSTONE_DBPASS@$database_host/keystone"
}

database_url=$(get_database_url)

echo "Setting database connection: $database_url."
iniset_sudo $conf database connection "$database_url"

echo "Configuring the Fernet token provider."
iniset_sudo $conf token provider fernet

echo "Creating the database tables for keystone."
sudo keystone-manage db_sync

echo "Initializing Fernet key repositories."
sudo keystone-manage fernet_setup \
    --keystone-user keystone \
    --keystone-group keystone

sudo keystone-manage credential_setup \
    --keystone-user keystone \
    --keystone-group keystone

echo "Bootstrapping the Identity service."
sudo keystone-manage bootstrap --bootstrap-password "$ADMIN_PASS" \
    --bootstrap-admin-url http://controller:5000/v3/ \
    --bootstrap-internal-url http://controller:5000/v3/ \
    --bootstrap-public-url http://controller:5000/v3/ \
    --bootstrap-region-id "$REGION"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure the Apache HTTP server
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

conf=/etc/httpd/conf/httpd.conf
echo "Configuring ServerName option in $conf to reference controller node."
echo "ServerName controller" | sudo tee -a $conf

sudo ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/

conf=/usr/share/keystone/wsgi-keystone.conf

if [ -f $conf ]; then
    echo "Identity service virtual hosts enabled."
else
    echo "Identity service virtual hosts not enabled."
    exit 1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Reduce memory usage (not in install-guide)

sudo sed -i --follow-symlinks '/WSGIDaemonProcess/ s/processes=[0-9]*/processes=1/' $conf

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize the installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Restarting httpd server."
sudo systemctl restart httpd && sudo systemctl enable httpd

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Setting Firewall and SELinux Modules "
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sudo firewall-cmd --add-port=5000/tcp --permanent
sudo firewall-cmd --reload

sudo touch keystone-httpd.te

cat <<EOF | sudo tee -a keystone-httpd.te

module keystone-httpd 1.0;

require {
        type httpd_t;
        type keystone_var_lib_t;
        type keystone_log_t;
        class file { create getattr ioctl open read write };
        class dir { add_name create write };
}

#============= httpd_t ==============
allow httpd_t keystone_var_lib_t:dir { add_name create write };
allow httpd_t keystone_var_lib_t:file { create open write getattr ioctl open read };
allow httpd_t keystone_log_t:dir { add_name write };
allow httpd_t keystone_log_t:file create;
EOF

sudo checkmodule -m -M -o keystone-httpd.mod keystone-httpd.te
sudo semodule_package --outfile keystone-httpd.pp --module keystone-httpd.mod
sudo semodule -i keystone-httpd.pp

sudo setsebool -P httpd_use_openstack on
sudo setsebool -P httpd_can_network_connect on
sudo setsebool -P httpd_can_network_connect_db on

# Set environment variables for authentication
export OS_USERNAME=$ADMIN_USER_NAME
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=$ADMIN_PROJECT_NAME
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3

#------------------------------------------------------------------------------
# Create a projects, users, and roles
#------------------------------------------------------------------------------

# Wait for keystone to come up
wait_for_keystone

echo "Creating service project."
openstack project create --domain default \
    --description "Service Project" \
    "$SERVICE_PROJECT_NAME"

echo "Creating demo project."
openstack project create --domain default \
    --description "Demo Project" \
    "$DEMO_PROJECT_NAME"

echo "Creating demo user."
openstack user create --domain default \
    --password "$DEMO_PASS" \
    "$DEMO_USER_NAME"

echo "Creating the user role."
openstack role create \
    "$USER_ROLE_NAME"

echo "Linking user role to demo project and user."
openstack role add \
    --project "$DEMO_PROJECT_NAME" \
    --user "$DEMO_USER_NAME" \
    "$USER_ROLE_NAME"

#------------------------------------------------------------------------------
# Verify operation
#------------------------------------------------------------------------------

echo "Verifying keystone installation."

# From this point on, we are going to use keystone for authentication
unset OS_AUTH_URL OS_PASSWORD

echo "Requesting an authentication token as an admin user."
openstack \
    --os-auth-url http://controller:5000/v3 \
    --os-project-domain-name Default \
    --os-user-domain-name Default \
    --os-project-name "$ADMIN_PROJECT_NAME" \
    --os-username "$ADMIN_USER_NAME" \
    --os-auth-type password \
    --os-password "$ADMIN_PASS" \
    token issue

echo "Requesting an authentication token for the demo user."
openstack \
    --os-auth-url http://controller:5000/v3 \
    --os-project-domain-name Default \
    --os-user-domain-name Default \
    --os-project-name "$DEMO_PROJECT_NAME" \
    --os-username "$DEMO_USER_NAME" \
    --os-auth-type password \
    --os-password "$DEMO_PASS" \
    token issue
