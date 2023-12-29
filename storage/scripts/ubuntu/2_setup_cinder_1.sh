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
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall qemu tgt

echo "Installing the supporting utility packages."
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall lvm2 thin-provisioning-tools

echo "Installing cinder."
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall cinder-common cinder-volume cinder-backup nfs-common nfs-util nfs-kernel-server

