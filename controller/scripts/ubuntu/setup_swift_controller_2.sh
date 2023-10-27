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

echo "Setting up database for swift."
setup_database swift "$SWIFT_DB_USER" "$SWIFT_DBPASS"

source "$CONFIG_DIR/admin-openstackrc.sh"

swift_admin_user=swift

# Wait for keystone to come up
wait_for_keystone

echo "Creating swift user."
openstack user create \
    --domain default \
    --password "$SWIFT_PASS" \
    "$swift_admin_user"

echo "Linking swift user, service tenant and admin role."
openstack role add \
    --project "$SERVICE_PROJECT_NAME" \
    --user "$swift_admin_user" \
    "$ADMIN_ROLE_NAME"

echo "Registering swift with keystone so that other services can locate it."
openstack service create \
    --name swift \
    --description "SkillPedia OpenStack Block Storage" \
    object-store

openstack endpoint create \
    --region "$REGION" \
    object-store public http://controller:8080/v1/AUTH_%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    object-store internal http://controller:8080/v1/AUTH_%\(project_id\)s

openstack endpoint create \
    --region "$REGION" \
    object-store admin http://controller:8080/v1

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function get_database_url {
    local db_user=$SWIFT_DB_USER
    local database_host=controller

    echo "mysql+pymysql://$db_user:$SWIFT_DBPASS@$database_host/swift"
}

database_url=$(get_database_url)

echo "Configuring proxy-server.conf."

conf=/etc/swift/proxy-server.conf

iniset_sudo $conf DEFAULT bind_port 8080
iniset_sudo $conf DEFAULT user swift
iniset_sudo $conf DEFAULT swift_dir /etc/swift

sudo sed -i "s/pipeline = .*/pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server/g" $conf

iniset_sudo $conf app:proxy-server use egg:swift#proxy
iniset_sudo $conf app:proxy-server account_autocreate True
iniset_sudo $conf filter:keystoneauth use egg:swift#keystoneauth
iniset_sudo $conf filter:keystoneauth operator_roles admin,member
iniset_sudo $conf filter:authtoken paste.filter_factory keystonemiddleware.auth_token:filter_factory
iniset_sudo $conf filter:authtoken www_authenticate_uri http://controller:5000
iniset_sudo $conf filter:authtoken auth_url http://controller:5000
iniset_sudo $conf filter:authtoken memcached_servers controller:11211
iniset_sudo $conf filter:authtoken auth_type password
iniset_sudo $conf filter:authtoken project_domain_id default
iniset_sudo $conf filter:authtoken user_domain_id default
iniset_sudo $conf filter:authtoken project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf filter:authtoken username "$swift_admin_user"
iniset_sudo $conf filter:authtoken password "$SWIFT_PASS"
iniset_sudo $conf filter:authtoken delay_auth_decision True

iniset_sudo $conf filter:cache use egg:swift#memcache
iniset_sudo $conf filter:cache memcache_servers controller:11211

