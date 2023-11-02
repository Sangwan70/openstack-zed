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
# Install and configure compute node
#------------------------------------------------------------------------------

echo "Installing networking components for compute node."
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall neutron-common neutron-linuxbridge-agent

