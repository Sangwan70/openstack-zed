#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

# Wait for keystone to come up
wait_for_keystone

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openstackrc.sh"

trove_admin_user=trove

# Wait for keystone to come up
wait_for_keystone

echo "Creating trove user and giving it admin role under service tenant."
openstack user create --domain default --password "$TROVE_PASS" "$trove_admin_user"

openstack role add --project "$SERVICE_PROJECT_NAME" --user "$trove_admin_user" "$ADMIN_ROLE_NAME"

echo "Creating the trove service entities."

openstack service create --name trove --description "Database" database

echo "Creating trove endpoints."
openstack endpoint create --region "$REGION" database public http://controller:8779/v1.0/%\(tenant_id\)s

openstack endpoint create --region "$REGION" database internal http://controller:8779/v1.0/%\(tenant_id\)s

openstack endpoint create --region "$REGION" database admin http://controller:8779/v1.0/%\(tenant_id\)s

#------------------------------------------------------------------------------
# Install the Database Service (trove)
#------------------------------------------------------------------------------

echo "Setting up database for trove."
setup_database trove "$TROVE_DB_USER" "$TROVE_DBPASS"
