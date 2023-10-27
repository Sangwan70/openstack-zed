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
# Set up Block Storage service controller (cinder controller node)
#------------------------------------------------------------------------------

source "$CONFIG_DIR/admin-openstackrc.sh"

cinder_admin_user=cinder

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install and configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing cinder."
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall cinder-common cinder-api
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall cinder-scheduler qemu-utils tgt

function get_database_url {
    local db_user=$CINDER_DB_USER
    local database_host=controller

    echo "mysql+pymysql://$db_user:$CINDER_DBPASS@$database_host/cinder"
}

database_url=$(get_database_url)

echo "Configuring cinder-api.conf."
conf=/etc/cinder/cinder.conf

echo "Setting database connection: $database_url."
iniset_sudo $conf database connection "$database_url"

echo "Configuring RabbitMQ message queue access."
iniset_sudo $conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller"

iniset_sudo $conf DEFAULT auth_strategy keystone

# Configure [keystone_authtoken] section.
iniset_sudo $conf keystone_authtoken www_authenticate_uri http://controller:5000
iniset_sudo $conf keystone_authtoken auth_url http://controller:5000
iniset_sudo $conf keystone_authtoken memcached_servers controller:11211
iniset_sudo $conf keystone_authtoken auth_type password
iniset_sudo $conf keystone_authtoken project_domain_id default
iniset_sudo $conf keystone_authtoken user_domain_id default
iniset_sudo $conf keystone_authtoken project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf keystone_authtoken username "$cinder_admin_user"
iniset_sudo $conf keystone_authtoken password "$CINDER_PASS"

iniset_sudo $conf DEFAULT my_ip "$(hostname_to_ip controller)"

iniset_sudo $conf oslo_concurrency lock_path /var/lib/cinder/tmp

echo "Populating the Block Storage database."
sudo cinder-manage db sync

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure Compute to use Block Storage
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Configuring Compute to use Block Storage."

conf=/etc/nova/nova.conf

iniset_sudo $conf cinder os_region_name "$REGION"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
conf=/etc/apache2/conf-available/cinder-wsgi.conf
sudo sed -i --follow-symlinks '/WSGIDaemonProcess/ s/processes=[0-9]*/processes=1/' $conf
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if ls -ld /etc/cinder | grep "root cinder"; then
    echo "Setting owner for /etc/cinder."
    sudo chown -v cinder:cinder /etc/cinder
else
    echo "Workaround for /etc/cinder owner no longer needed."
fi

echo "Restarting the Compute API service."
sudo systemctl restart nova-api

echo "Restarting the Block Storage services."
sudo systemctl restart cinder-scheduler
sudo systemctl restart apache2

AUTH="source $CONFIG_DIR/admin-openstackrc.sh"
echo -n "Waiting for cinder to start."
until node_ssh controller "$AUTH; openstack volume service list" >/dev/null \
        2>&1; do
    echo -n .
    sleep 1
done
echo
