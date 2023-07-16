#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Install the Image Service (glance).
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Setting up database for glance."
setup_database glance "$GLANCE_DB_USER" "$GLANCE_DBPASS"

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openstackrc.sh"

glance_admin_user=glance

# Wait for keystone to come up
wait_for_keystone

echo "Creating glance user and giving it admin role under service tenant."
openstack user create \
    --domain default \
    --project "$SERVICE_PROJECT_NAME" \
    --password "$GLANCE_PASS" \
    "$glance_admin_user"

openstack role add \
    --project "$SERVICE_PROJECT_NAME" \
    --user "$glance_admin_user" \
    "$ADMIN_ROLE_NAME"

echo "Registering glance with keystone so that other services can locate it."
openstack service create \
    --name glance \
    --description "OpenStack Image" \
    image

echo "Creating the Image service API endpoints."
openstack endpoint create \
    --region "$REGION" \
    image public http://controller:9292

openstack endpoint create \
    --region "$REGION" \
    image internal http://controller:9292

openstack endpoint create \
    --region "$REGION" \
    image admin http://controller:9292

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install and configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing glance."
sudo dnf install -y openstack-glance

function get_database_url {
    local db_user=$GLANCE_DB_USER
    local database_host=controller

    echo "mysql+pymysql://$db_user:$GLANCE_DBPASS@$database_host/glance"
}

database_url=$(get_database_url)
echo "Database connection: $database_url."

echo "Configuring glance-api.conf."
conf=/etc/glance/glance-api.conf

# Database
iniset_sudo $conf database connection "$database_url"

# Keystone_authtoken
iniset_sudo $conf keystone_authtoken www_authenticate_uri http://controller:5000
iniset_sudo $conf keystone_authtoken auth_url http://controller:5000
iniset_sudo $conf keystone_authtoken memcached_servers controller:11211
iniset_sudo $conf keystone_authtoken auth_type password
iniset_sudo $conf keystone_authtoken project_domain_name Default
iniset_sudo $conf keystone_authtoken user_domain_name Default
iniset_sudo $conf keystone_authtoken project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf keystone_authtoken username "$glance_admin_user"
iniset_sudo $conf keystone_authtoken password "$GLANCE_PASS"

# Paste_deploy
iniset_sudo $conf paste_deploy flavor "keystone"

# glance_store
iniset_sudo $conf glance_store stores "file,http"
iniset_sudo $conf glance_store default_store file
iniset_sudo $conf glance_store filesystem_store_datadir /var/lib/glance/images/

echo "Creating the database tables for glance."
sudo glance-manage db_sync

sudo chmod 640 /etc/glance/glance-api.conf
sudo chown -R root:glance /etc/glance/
sudo chown -R glance:glance /var/log/glance/

echo "Restarting glance service."
sudo systemctl start openstack-glance-api && sudo systemctl enable openstack-glance-api 
sudo systemctl status openstack-glance-api 
 
echo "Enabling Firewall.."
sudo firewall-cmd --permanent  --add-port={9191,9292}/tcp 
sudo firewall-cmd --reload 

echo "Building and Inserting SELinux Module for Glance API "

sudo touch glanceapi.te
cat << EOF | sudo tee -a glanceapi.te
module glanceapi 1.0;

require {
        type glance_api_t;
        type mysqld_exec_t;
        type mysqld_safe_exec_t;
        type rpm_exec_t;
        type hostname_exec_t;
        type sudo_exec_t;
        type httpd_config_t;
        type iscsid_exec_t;
        type gpg_exec_t;
        type crontab_exec_t;
        type consolehelper_exec_t;
        class dir search;
        class file {getattr open read};
}

#============= glance_api_t ==============
allow glance_api_t httpd_config_t: dir search;
allow glance_api_t mysqld_exec_t: file getattr;
allow glance_api_t mysqld_safe_exec_t: file getattr;
allow glance_api_t gpg_exec_t: file getattr;
allow glance_api_t hostname_exec_t: file getattr;
allow glance_api_t rpm_exec_t: file getattr;
allow glance_api_t sudo_exec_t: file getattr;
allow glance_api_t consolehelper_exec_t: file getattr;
allow glance_api_t crontab_exec_t: file getattr;
allow glance_api_t iscsid_exec_t: file {getattr open read};
EOF

echo "Building SELinux Modules for Glance"

sudo checkmodule -m -M -o glanceapi.mod glanceapi.te
sudo semodule_package --outfile glanceapi.pp --module glanceapi.mod
sudo semodule -i glanceapi.pp

sudo setsebool -P glance_api_can_network on

#------------------------------------------------------------------------------
# Verify the Image Service installation
#------------------------------------------------------------------------------

echo -n "Waiting for glance to start."
until openstack image list >/dev/null 2>&1; do
    sleep 1
    echo -n .
done
echo

echo "Adding pre-downloaded CirrOS image as $CIRROS_IMG_NAME to glance."

# install-guide changed from openstack to glance client, but did not
#     change --public to --visibility public
glance image-create --name "$CIRROS_IMG_NAME" \
    --file "$HOME/img/$(basename $CIRROS_URL)" \
    --disk-format qcow2 --container-format bare \
    --visibility public

echo "Verifying that the image was successfully added to the service."

echo "glance image-list"
glance image-list
