#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

echo "Installing Trove"

# sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall python3-trove trove-common trove-api trove-taskmanager trove-conductor python3-troveclient
sudo pip3 install trove-dashboard
sudo cp /usr/local/lib/python3.10/dist-packages/trove_dashboard/enabled/_[1-9]*.py \
      /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
cd /usr/share/openstack-dashboard
sudo python3 manage.py compress

