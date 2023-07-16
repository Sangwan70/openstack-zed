#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$TOP_DIR/config/openstack"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Install Compute controller services
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Setting up database nova."
setup_database nova "$NOVA_DB_USER" "$NOVA_DBPASS"

echo "Setting up database nova_api."
setup_database nova_api "$NOVA_DB_USER" "$NOVA_DBPASS"

echo "Setting up first cell database."
# nova_cell0 is default name for first cell database

setup_database nova_cell0 "$NOVA_DB_USER" "$NOVA_DBPASS"

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openrc.sh"

nova_admin_user=nova
placement_admin_user=placement

# Wait for keystone to come up
wait_for_keystone

echo "Creating nova user and giving it the admin role."
openstack user create \
    --domain default  \
    --password "$NOVA_PASS" \
    "$nova_admin_user"

openstack role add \
    --project "$SERVICE_PROJECT_NAME" \
    --user "$nova_admin_user" \
    "$ADMIN_ROLE_NAME"

echo "Creating the nova service entity."
openstack service create \
    --name nova \
    --description "OpenStack Compute" \
    compute

echo "Creating nova endpoints."
openstack endpoint create \
    --region "$REGION" \
    compute public http://controller:8774/v2.1

openstack endpoint create \
    --region "$REGION" \
    compute internal http://controller:8774/v2.1

openstack endpoint create \
    --region "$REGION" \
    compute admin http://controller:8774/v2.1

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install and configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing nova for controller node."
sudo dnf install -y openstack-nova-api openstack-nova-conductor openstack-nova-novncproxy openstack-nova-scheduler

conf=/etc/nova/nova.conf

# Configure [api_database] section.
database_url="mysql+pymysql://$NOVA_DB_USER:$NOVA_DBPASS@controller/nova_api"
echo "Setting API database connection: $database_url."
iniset_sudo $conf api_database connection "$database_url"

# Configure [database] section.
database_url="mysql+pymysql://$NOVA_DB_USER:$NOVA_DBPASS@controller/nova"
echo "Setting database connection: $database_url."
iniset_sudo $conf database connection "$database_url"

echo "Configuring nova services."

echo "Configuring RabbitMQ message queue access."
iniset_sudo $conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller:5672"

# Configure [api] section.
iniset_sudo $conf api auth_strategy keystone

# Configure [keystone_authtoken] section.
iniset_sudo $conf keystone_authtoken www_authenticate_uri http://controller:5000/
iniset_sudo $conf keystone_authtoken auth_url http://controller:5000/
iniset_sudo $conf keystone_authtoken memcached_servers controller:11211
iniset_sudo $conf keystone_authtoken auth_type password
iniset_sudo $conf keystone_authtoken project_domain_name Default
iniset_sudo $conf keystone_authtoken user_domain_name Default
iniset_sudo $conf keystone_authtoken project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf keystone_authtoken username "$nova_admin_user"
iniset_sudo $conf keystone_authtoken password "$NOVA_PASS"

# Configure [DEFAULT] section.
iniset_sudo $conf DEFAULT metadata_listen_port 8775
iniset_sudo $conf DEFAULT state_path /var/lib/nova
iniset_sudo $conf DEFAULT enabled_apis osapi_compute,metadata
iniset_sudo $conf DEFAULT my_ip "$(hostname_to_ip controller)"
iniset_sudo $conf DEFAULT use_neutron true
iniset_sudo $conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

# Configure [VNC] section.
iniset_sudo $conf vnc enabled true
iniset_sudo $conf vnc server_listen '$my_ip'
iniset_sudo $conf vnc server_proxyclient_address '$my_ip'

# Configure [glance] section.
iniset_sudo $conf glance api_servers http://controller:9292

# Configure [oslo_concurrency] section.
iniset_sudo $conf oslo_concurrency lock_path /var/lib/nova/tmp
iniset_sudo $conf wsgi api_paste_config /etc/nova/api-paste.ini

iniset_sudo $conf oslo_policy policy_file policy.yaml


sudo sed -i "/^log_dir/ d" $conf

echo "Configuring access to the Placement service."
iniset_sudo $conf placement region_name RegionOne
iniset_sudo $conf placement project_domain_name Default
iniset_sudo $conf placement project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf placement auth_type password
iniset_sudo $conf placement user_domain_name Default
iniset_sudo $conf placement auth_url http://controller:5000/v3
iniset_sudo $conf placement username "$placement_admin_user"
iniset_sudo $conf placement password "$PLACEMENT_PASS"

sudo oslopolicy-convert-json-to-yaml --namespace placement --policy-file /etc/nova/policy.json --output-file /etc/nova/policy.yaml
sudo chown root.nova /etc/nova/policy.yaml

echo "Populating the nova-api databases."
sudo nova-manage api_db sync

echo "Registering the cell0 database."
sudo nova-manage cell_v2 map_cell0

echo "Creating the cell1 cell."
sudo nova-manage cell_v2 create_cell --name=cell1 --verbose

echo "Populating the nova database."
sudo nova-manage db sync

echo "Verifying nova cell0 and cell1 are registered correctly."
sudo nova-manage cell_v2 list_cells

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openrc.sh"

# Wait for keystone to come up
wait_for_keystone

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Restarting nova services."
declare -a nova_services=(openstack-nova-api openstack-nova-scheduler openstack-nova-conductor \
    openstack-nova-novncproxy)

for nova_service in "${nova_services[@]}"; do
    echo "Restarting and enabling $nova_service."
    sudo systemctl restart "$nova_service"
    sudo systemctl enable "$nova_service"
done

echo "Opening Firewall. "

sudo firewall-cmd --permanent --add-port={6080,6081,6082,8774,8775,8778}/tcp 
sudo firewall-cmd --reload

sudo semanage port -a -t http_port_t -p tcp 8778

sudo touch novaapi.te

cat <<EOF | sudo tee -a novaapi.te 
module novaapi 1.0;

require {
        type rpm_exec_t;
        type hostname_exec_t;
        type nova_t;
        type gpg_exec_t;
        class file getattr;
}

#============= nova_t ==============
allow nova_t gpg_exec_t:file getattr;
allow nova_t hostname_exec_t:file getattr;
allow nova_t rpm_exec_t:file getattr;
EOF

sudo checkmodule -m -M -o novaapi.mod novaapi.te
sudo semodule_package --outfile novaapi.pp --module novaapi.mod
sudo semodule -i novaapi.pp

#------------------------------------------------------------------------------
# Verify the Compute controller installation (not in install-guide)
#------------------------------------------------------------------------------

echo -n "Verifying operation of the Compute service."
until openstack service list 2>/dev/null; do
    sleep 1
    echo -n .
done
echo

echo "Checking nova endpoints."
openstack catalog list

echo "Checking nova images."
openstack image list
