#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/openstack"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

function apt_download {
    echo "apt_download: $*"
    sudo apt install -y --download-only "$@"
}

# Download packages for all nodes

# Other dependencies
apt_download  python3-dev python3-pip

# Cinder Volumes
apt_download lvm2 cinder-volume thin-provisioning-tools

# Nova Compute
apt_download nova-compute nova-compute-qemu qemu sysfsutils

# Neutron Compute
apt_download neutron-linuxbridge-agent

# Heat
apt_download heat-api heat-api-cfn heat-engine python3-heatclient

# Swift Storage
apt_download xfsprogs rsync \
    swift swift-account swift-container swift-object
