#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$CONFIG_DIR/openstack"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Set up Block Storage service controller (cinder controller node)
#------------------------------------------------------------------------------

echo "Setting up database for cinder."
setup_database cinder "$CINDER_DB_USER" "$CINDER_DBPASS"

source "$CONFIG_DIR/admin-openstackrc.sh"

cinder_admin_user=cinder

# Wait for keystone to come up
wait_for_keystone

echo "Creating cinder user."
openstack user create \
    --domain default \
    --password "$CINDER_PASS" \
    "$cinder_admin_user"

echo "Linking cinder user, service tenant and admin role."
openstack role add \
    --project "$SERVICE_PROJECT_NAME" \
    --user "$cinder_admin_user" \
    "$ADMIN_ROLE_NAME"

echo "Registering cinder with keystone so that other services can locate it."
openstack service create \
    --name cinderv2 \
    --description "OpenStack Block Storage" \
    volumev2

openstack service create \
    --name cinderv3 \
    --description "OpenStack Block Storage" \
    volumev3

openstack endpoint create \
    --region "$REGION" \
    volumev2 public http://controller:8776/v2/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev2 internal http://controller:8776/v2/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev2 admin http://controller:8776/v2/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev3 public http://controller:8776/v3/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev3 internal http://controller:8776/v3/%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    volumev3 admin http://controller:8776/v3/%\(project_id\)s

