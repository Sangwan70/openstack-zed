#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/openstack"
source "$LIB_DIR/functions.guest.sh"

indicate_current_auto

exec_logfile

#------------------------------------------------------------------------------
# Upgrade installed packages and the kernel
# Keep our changes to /etc/sudoers from tripping up apt

echo "Installing OpenStack client."
sudo apt install -y -o Dpkg::Options::="--force-confdef" python3-openstackclient

sudo DEBIAN_FRONTEND=noninteractive apt \
   -o Dpkg::Options::="--force-confdef" -y upgrade
sudo apt -y dist-upgrade

# Clean apt cache
sudo apt -y autoremove
sudo apt -y clean

# management. We install and use the legacy tools for the time being.
sudo apt install -y ifupdown

echo "Installing curl, tree (they are small and useful)."
sudo apt install -y curl tree
