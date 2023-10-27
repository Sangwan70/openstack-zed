#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"
source "$CONFIG_DIR/admin-openrc.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Install and configure a storage node
#------------------------------------------------------------------------------

MY_MGMT_IP=$(get_node_ip_in_network "$(hostname)" "mgmt")
echo "IP address of this node's interface in management network: $MY_MGMT_IP."

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Configuring LVM physical and logical volumes."

cinder_dev=sdd

sudo pvcreate /dev/$cinder_dev
sudo vgcreate cinder-vol1 /dev/$cinder_dev

conf=/etc/lvm/lvm.conf

# echo "Setting LVM filter line in $conf to only allow /dev/$cinder_dev."
# sudo sed -i '0,/# filter = / {s|# filter = .*|filter = [ "a/'$cinder_dev'/", "r/.*/"]|}' $conf

# echo "Verifying LVM filter."
# grep "^[[:space:]]\{1,\}filter" $conf

echo "Setting LVM filter line in $conf to only allow /dev/$cinder_dev."
sudo sed -i '0,/# filter = / {s|# filter = .*|filter = [ "a/'$cinder_dev'/" ]|}' $conf

echo "Verifying LVM filter."
grep "^[[:space:]]\{1,\}filter" $conf

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

conf=/etc/cinder/cinder.conf
echo "Configuring $conf."

function get_database_url {
    local db_user=$CINDER_DB_USER
    local database_host=controller

    echo "mysql+pymysql://$db_user:$CINDER_DBPASS@$database_host/cinder"
}

database_url=$(get_database_url)
cinder_admin_user=cinder

echo "Setting database connection: $database_url."
iniset_sudo $conf database connection "$database_url"

echo "Configuring RabbitMQ message queue access."
iniset_sudo $conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller"

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

iniset_sudo $conf DEFAULT my_ip "$MY_MGMT_IP"
iniset_sudo $conf DEFAULT iscsi_protocol iscsi
iniset_sudo $conf DEFAULT iscsi_helper tgtadm
iniset_sudo $conf DEFAULT enabled_backends lvm
iniset_sudo $conf DEFAULT glance_api_servers http://controller:9292

iniset_sudo $conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
iniset_sudo $conf lvm volume_group cinder-vol1

iniset_sudo $conf oslo_concurrency lock_path /var/lib/cinder/tmp

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Restarting cinder service."
sudo systemctl restart tgt && sudo systemctl enable tgt
sudo systemctl restart  cinder-volume && sudo systemctl enable  cinder-volume 

