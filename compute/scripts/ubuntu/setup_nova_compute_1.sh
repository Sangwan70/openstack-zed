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
# Install and configure a compute node
#------------------------------------------------------------------------------

echo "Installing nova for compute node."
sudo apt install -y -o Dpkg::Options::="--force-confdef" python3-openstackclient
sudo apt install -y --reinstall -o DPkg::options::=--force-confmiss nova-common nova-compute 
sudo apt install -y --reinstall -o DPkg::options::=--force-confmiss nova-compute-qemu

