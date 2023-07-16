#!/usr/bin/env bash
set -o errexit -o nounset
TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)
source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"
exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Create the provier (external) network and a subnet on it
#------------------------------------------------------------------------------

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openstackrc.sh"

# Wait for neutron to start
wait_for_neutron

function wait_for_agent {
    local agent=$1

    echo -n "Waiting for neutron agent $agent."
    (
    source "$CONFIG_DIR/admin-openstackrc.sh"
    while openstack network agent-list|grep "$agent"|grep "XXX" >/dev/null; do
        sleep 1
        echo -n .
    done
    echo
    )
}

wait_for_agent neutron-l3-agent

echo "linuxbridge-agent and dhcp-agent must be up before we can add interfaces."
wait_for_agent neutron-linuxbridge-agent
wait_for_agent neutron-dhcp-agent

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create the provider network
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Not in install-guide:
echo -n "Waiting for DHCP namespace."
until [ "$(ip netns | grep -c -o "^qdhcp-[a-z0-9-]*")" -gt 0 ]; do
    sleep 1
    echo -n .
done
echo

echo -n "Waiting for bridge to show up."
# Bridge names are something like brq219ddb93-c9
until [ "$(nmcli connection show | grep -c -o "^brq[a-z0-9-]*")" -gt 0 ]; do
    sleep 1
    echo -n .
done
echo

sudo nmcli connection show
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
