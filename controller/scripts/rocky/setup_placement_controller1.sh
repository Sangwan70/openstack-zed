#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$TOP_DIR/config/openstack"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openrc.sh"

echo "Listing available resource classes and traits."
openstack --os-placement-api-version 1.6 trait list --sort-column name

sudo oslopolicy-convert-json-to-yaml --namespace placement --policy-file /etc/placement/policy.json --output-file /etc/placement/policy.yaml
sudo chown root.placement /etc/placement/policy.yaml

echo "Restarting httpd server."
sudo systemctl restart httpd

# difference to install-guide: root privileges seem to be needed for the
#     placement-status upgrade check
echo "Performing status check."
sudo placement-status upgrade check

