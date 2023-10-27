#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"
source "$CONFIG_DIR/openstack"

exec_logfile

indicate_current_auto

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install the components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing additional packages for self-service networks."
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall neutron-common
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall neutron-server neutron-plugin-ml2
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall neutron-metadata-agent
