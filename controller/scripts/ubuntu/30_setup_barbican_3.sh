#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$LIB_DIR/functions.guest.sh"

source "$CONFIG_DIR/credentials"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

BARBICAN_DB_USER=barbican
BARBICAN_DBPASS=barbican_db_secret
BARBICAN_PASS=barbican_user_secret

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openstackrc.sh"

barbican_admin_user=barbican

sudo su -s /bin/sh -c "barbican-manage db upgrade" barbican
echo "Showing barbican secret list."
openstack secret list

echo "Getting a token."
token=$(openstack token issue -cid -fvalue)

echo "token: $token"

echo "Using curl, storing a payload string into a barbican secret."
curl -s -H "X-Auth-Token: $token" \
    -X POST -H 'content-type:application/json' -H 'X-Project-Id:12345' \
    -d '{"payload": "my-secret-here", "payload_content_type": "text/plain"}' \
    http://localhost:9311/v1/secrets

echo "Getting URI for secret."
# Assuming the list contains only one item
uri=$(openstack secret list -c"Secret href" -fvalue)
echo "URI: $uri"

echo "Showing payload via curl."
curl -s -H "X-Auth-Token: $token" \
    -H 'Accept: text/plain' -H 'X-Project-Id: 12345' \
    "$uri"

echo "Showing payload using barbican client."
openstack secret get "$uri" --payload -fvalue

echo "Deleting secret."
openstack secret delete "$uri"

echo "Using the barbican client, creating a named barbican secret."
openstack secret store --name test_name

echo "Showing named barbican secret."
openstack secret list --name test_name -cName -fvalue

echo "Getting URI for secret."
uri=$(openstack secret list --name test_name -c"Secret href" -fvalue)

echo "Writing payload."
openstack secret update "$uri" "my_payload"

echo "Showing secret payload."
openstack secret get "$uri"

echo "Showing payload using barbican client."
openstack secret get "$uri" --payload -fvalue

echo "Deleting secret."
openstack secret delete "$uri"
