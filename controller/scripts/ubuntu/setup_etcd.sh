#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Install the Image Service (glance).
#------------------------------------------------------------------------------
sudo apt -y install etcd

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

conf=/etc/default/etcd

iniset_sudo $conf no_section ETCD_DATA_DIR "/var/lib/etcd/default.etcd"
iniset_sudo $conf no_section ETCD_LISTEN_PEER_URLS "http://10.10.0.11:2380"
iniset_sudo $conf no_section ETCD_LISTEN_CLIENT_URLS "http://10.10.0.11:2379"
iniset_sudo $conf no_section ETCD_NAME "controller"
#[Clustering]
iniset_sudo $conf no_section ETCD_INITIAL_ADVERTISE_PEER_URLS "http://10.10.0.11:2380"
iniset_sudo $conf no_section ETCD_ADVERTISE_CLIENT_URLS "http://10.10.0.11:2379"
iniset_sudo $conf no_section ETCD_INITIAL_CLUSTER "controller=http://10.10.0.11:2380"
iniset_sudo $conf no_section ETCD_INITIAL_CLUSTER_TOKEN "etcd-cluster-01"
iniset_sudo $conf no_section ETCD_INITIAL_CLUSTER_STATE "new"

echo "Restarting glance service."
sudo systemctl enable etcd
sudo systemctl start etcd

