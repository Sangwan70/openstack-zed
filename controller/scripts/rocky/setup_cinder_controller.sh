#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Set up Block Storage service controller (cinder controller node)
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Setting up database for cinder."
setup_database cinder "$CINDER_DB_USER" "$CINDER_DBPASS"

source "$CONFIG_DIR/admin-openstackrc.sh"

cinder_admin_user=cinder

# Wait for keystone to come up
wait_for_keystone

echo "Creating cinder user."
openstack user create \
    --domain default \
    --password "$CINDER_PASS" \
    "$cinder_admin_user"

echo "Linking cinder user, service tenant and admin role."
openstack role add \
    --project "$SERVICE_PROJECT_NAME" \
    --user "$cinder_admin_user" \
    "$ADMIN_ROLE_NAME"

echo "Registering cinder with keystone so that other services can locate it."
openstack service create \
    --name cinderv2 \
    --description "OpenStack Block Storage" \
    volumev2

openstack service create \
    --name cinderv3 \
    --description "OpenStack Block Storage" \
    volumev3

openstack endpoint create \
    --region "$REGION" \
    volumev2 public http://controller:8776/v2/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev2 internal http://controller:8776/v2/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev2 admin http://controller:8776/v2/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev3 public http://controller:8776/v3/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev3 internal http://controller:8776/v3/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev3 admin http://controller:8776/v3/%\(project_id\)s

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install and configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing cinder."
sudo dnf install -y openstack-cinder qemu-img*

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

echo "Restarting the Block Storage services."
declare -a all_services=(openstack-cinder-scheduler openstack-cinder-api openstack-nova-api \
    openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy httpd)

for a_service in "${all_services[@]}"; do
    echo "Restarting and enabling $a_service."
    sudo systemctl restart "$a_service"
    sudo systemctl enable "$a_service"
done

echo "Restarting httpd and Nova services."
declare -a nova_services=(openstack-nova-api \
    openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy httpd)

for nova_service in "${nova_services[@]}"; do
    echo "Restarting $nova_service."
    sudo systemctl restart "$nova_service"
done

sudo firewall-cmd --add-port={8776,9696}/tcp --permanent
sudo firewall-cmd --reload

AUTH="source $CONFIG_DIR/admin-openstackrc.sh"
echo -n "Waiting for cinder to start."
until node_ssh controller "$AUTH; openstack volume service list" >/dev/null \
        2>&1; do
    echo -n .
    sleep 1
done
echo
