#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"
source "$CONFIG_DIR/admin-openstackrc.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Install and configure a storage node
#------------------------------------------------------------------------------

MY_MGMT_IP=$(get_node_ip_in_network "$(hostname)" "mgmt")
echo "IP address of this node's interface in management network: $MY_MGMT_IP."

echo "Installing qemu support package for non-raw image types."
sudo yum install -y qemu-kvm lvm2

echo "Configuring LVM physical and logical volumes."

cinder_dev=sdd


sudo pvcreate /dev/$cinder_dev
sudo vgcreate cinder-volumes /dev/$cinder_dev

conf=/etc/lvm/lvm.conf

echo "Setting LVM filter line in $conf to only allow /dev/$cinder_dev."
sudo sed -i '0,/# filter = / {s|# filter = .*|filter = [ "a/'$cinder_dev'/", "r/.*/"]|}' $conf

echo "Verifying LVM filter."
grep "^[[:space:]]\{1,\}filter" $conf

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install and configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing cinder."
sudo yum install -y openstack-cinder targetcli

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

iniset_sudo $conf DEFAULT target_helper lioadm

iniset_sudo $conf backend_defaults target_helper lioadm

iniset_sudo $conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
iniset_sudo $conf lvm volume_group cinder-volumes
iniset_sudo $conf lvm target_ip_address "$MY_MGMT_IP"
iniset_sudo $conf lvm iscsi_protocol iscsi
iniset_sudo $conf lvm iscsi_helper lioadm

iniset_sudo $conf DEFAULT target_ip_address "$MY_MGMT_IP"
iniset_sudo $conf DEFAULT enable_v3_api True
iniset_sudo $conf DEFAULT state_path /var/lib/cinder
iniset_sudo $conf DEFAULT volumes_dir /var/lib/cinder

iniset_sudo $conf DEFAULT enabled_backends lvm
iniset_sudo $conf DEFAULT glance_api_servers http://controller:9292

iniset_sudo $conf oslo_concurrency lock_path /var/lib/cinder/tmp

sudo chmod 640 $conf
sudo chgrp cinder $conf

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Restarting cinder service."
sudo systemctl restart openstack-cinder-volume
sudo systemctl enable openstack-cinder-volume

sudo systemctl restart target.service
sudo systemctl enable target.service

sudo touch iscsiadm.te

cat <<EOF | sudo tee -a iscsiadm.te
module iscsiadm 1.0;

require {
        type iscsid_t;
        class capability dac_override;
}

#============= iscsid_t ==============
allow iscsid_t self:capability dac_override;
EOF

sudo checkmodule -m -M -o iscsiadm.mod iscsiadm.te
sudo semodule_package --outfile iscsiadm.pp --module iscsiadm.mod
sudo semodule -i iscsiadm.pp

sudo firewall-cmd --add-service=iscsi-target --permanent
sudo firewall-cmd --reload

#------------------------------------------------------------------------------
# Verify Cinder operation
#------------------------------------------------------------------------------

echo "Verifying Block Storage installation on controller node."

echo "Sourcing the admin credentials."
AUTH="source $CONFIG_DIR/admin-openstackrc.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Restarting restarting cinder-scheduler."
node_ssh controller "sudo systemctl restart openstack-cinder-api"
node_ssh controller "sudo systemctl restart openstack-cinder-scheduler"

echo -n "Waiting for cinder to start."
until node_ssh controller "$AUTH; openstack volume service list" >/dev/null \
        2>&1; do
    echo -n .
    sleep 1
done
echo
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "openstack volume service list is available:"
node_ssh controller "$AUTH; openstack volume service list"


function check_cinder_services {

    # It takes some time for cinder to detect its services and update its
    # status. This method will wait for 60 seconds to get the status of the
    # cinder services.
    local i=0
    while : ; do
        # Check service-list every 5 seconds
        if [ $(( i % 5 )) -ne 0 ]; then
            if ! node_ssh controller "$AUTH; openstack volume service list" \
                    2>&1 | grep -q down; then
                echo
                echo "All cinder services seem to be up and running."
                node_ssh controller "$AUTH; openstack volume service list"
                return 0
            fi
        fi
        if [[ "$i" -eq "60" ]]; then
            echo
            echo "ERROR Cinder services are not working as expected."
            node_ssh controller "$AUTH; openstack volume service list"
            exit 1
        fi
        i=$((i + 1))
        echo -n .
        sleep 1
    done
}

# To avoid race conditions which were causing Cinder Volumes script to fail,
# check the status of the cinder services. Cinder takes a few seconds before it
# is aware of the exact status of its services.
echo -n "Waiting for all cinder services to start."
check_cinder_services

#------------------------------------------------------------------------------
# Verify the Block Storage installation
# (partial implementation without instance)
#------------------------------------------------------------------------------

echo "Sourcing the demo credentials."
AUTH="source $CONFIG_DIR/demo-openstackrc.sh"

echo "openstack volume create --size 1 volume1"
node_ssh controller "$AUTH; openstack volume create --size 1 volume1"

echo -n "Waiting for cinder to list the new volume."
until node_ssh controller "$AUTH; openstack volume list| grep volume1" > /dev/null 2>&1; do
    echo -n .
    sleep 1
done
echo

function wait_for_cinder_volume {

    echo -n 'Waiting for cinder volume to become available.'
    local i=0
    while : ; do
        # Check list every 5 seconds
        if [ $(( i % 5 )) -ne 0 ]; then
            if node_ssh controller "$AUTH; openstack volume list" 2>&1 |
                    grep -q "volume1 .*|.* available"; then
                echo
                return 0
            fi
        fi
        if [ $i -eq 20 ]; then
            echo
            echo "ERROR Failed to create cinder volume."
            node_ssh controller "$AUTH; openstack volume list"
            exit 1
        fi
        i=$((i + 1))
        echo -n .
        sleep 1
    done
}

# Wait for cinder volume to be created
wait_for_cinder_volume

echo "Volume successfully created:"
node_ssh controller "$AUTH; openstack volume list"

echo "Deleting volume."
node_ssh controller "$AUTH; openstack volume delete volume1"

echo "openstack volume list"
node_ssh controller "$AUTH; openstack volume list"
