#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing placement-api for controller node."
sudo apt-get -y -o DPkg::options::=--force-confmiss --reinstall install placement-common placement-api
echo "Installing python3-pip."
sudo apt-get -y -o DPkg::options::=--force-confmiss --reinstall install python3-pip
echo "Installing the placement client."
sudo pip3 install osc-placement

