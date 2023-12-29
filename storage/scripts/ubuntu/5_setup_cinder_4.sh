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

#------------------------------------------------------------------------------
# Verify Cinder operation
#------------------------------------------------------------------------------

sudo touch /etc/exports

echo "/var/lib/nfs-share 10.10.0.0/24(rw,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
sudo systemctl enable --now nfs-server
sudo systemctl status nfs-server

exit 0

echo "Verifying Block Storage installation on controller node."

echo "Sourcing the admin credentials."
AUTH="source $CONFIG_DIR/admin-openstackrc.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Restarting restarting cinder-scheduler."
node_ssh controller "sudo systemctl restart cinder-scheduler.service"

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

# is aware of the exact status of its services.
echo -n "Waiting for all cinder services to start."
check_cinder_services

#------------------------------------------------------------------------------
# Verify the Block Storage installation
#------------------------------------------------------------------------------

echo "Sourcing the demo credentials."
AUTH="source $CONFIG_DIR/demo-openrc.sh"

echo "openstack volume create --size 1 volume2"
node_ssh controller "$AUTH; openstack volume create --size 1 volume2"

echo -n "Waiting for cinder to list the new volume."
until node_ssh controller "$AUTH; openstack volume list| grep volume2" > /dev/null 2>&1; do
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
                    grep -q "volume2 .*|.* available"; then
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
node_ssh controller "$AUTH; openstack volume delete volume2"

echo "openstack volume list"
node_ssh controller "$AUTH; openstack volume list"


