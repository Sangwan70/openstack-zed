#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Set up Block Storage service controller (cinder controller node)
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install  components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing swift."
sudo apt install -y swift swift-account swift-container swift-object xfsprogs python3-swift python3-swiftclient \
       python3-keystoneclient python3-keystonemiddleware
sudo apt install -y swift-proxy python3-memcache

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Obtain the proxy service configuration file from the Object Storage repository
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sudo curl -o /etc/swift/proxy-server.conf \
	https://opendev.org/openstack/swift/raw/branch/stable/victoria/etc/proxy-server.conf-sample

