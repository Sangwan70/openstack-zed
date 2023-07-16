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

# Create or edit the /etc/rsyncd.conf file
conf=/etc/rsyncd.conf

iniset_sudo_no_section $conf uid swift
iniset_sudo_no_section $conf gid swift
iniset_sudo_no_section $conf log\ file /var/log/rsyncd.log
iniset_sudo_no_section $conf pid\ file /var/run/rsyncd.pid
iniset_sudo_no_section $conf address $MY_MGMT_IP

iniset_sudo $conf account max\ connections 2
iniset_sudo $conf account path /srv/node/
iniset_sudo $conf account read\ only False
iniset_sudo $conf account lock\ file /var/lock/account.lock

iniset_sudo $conf container max\ connections 2
iniset_sudo $conf container path  /srv/node/
iniset_sudo $conf container read\ only False
iniset_sudo $conf container lock\ file /var/lock/container.lock

iniset_sudo $conf object max\ connections 2
iniset_sudo $conf object path /srv/node/
iniset_sudo $conf object read\ only False
iniset_sudo $conf object lock\ file /var/lock/object.lock

# sudo touch /etc/default/rsync

conf=/etc/default/rsync
iniset_sudo_no_section $conf RSYNC_ENABLE true 

echo "start the rsync service."
sudo systemctl enable rsync.service
sudo systemctl start rsync.service
sudo systemctl status rsync.service

