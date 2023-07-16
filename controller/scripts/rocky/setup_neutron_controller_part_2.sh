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
# Set up OpenStack Networking (neutron) for controller node.
#------------------------------------------------------------------------------

source "$CONFIG_DIR/admin-openstackrc.sh"

neutron_admin_user=neutron

# Wait for keystone to come up
wait_for_keystone

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure the metadata agent
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Installing additional packages for self-service networks."
sudo dnf install -y \
    openstack-neutron openstack-neutron-ml2 ebtables


echo "Configuring the metadata agent."
conf=/etc/neutron/metadata_agent.ini
iniset_sudo $conf DEFAULT nova_metadata_host controller
iniset_sudo $conf DEFAULT metadata_proxy_shared_secret "$METADATA_SECRET"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure the Compute service to use the Networking service
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Configuring Compute to use Networking."
conf=/etc/nova/nova.conf
iniset_sudo $conf neutron auth_url http://controller:5000
iniset_sudo $conf neutron auth_type password
iniset_sudo $conf neutron project_domain_name default
iniset_sudo $conf neutron user_domain_name default
iniset_sudo $conf neutron region_name "$REGION"
iniset_sudo $conf neutron project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf neutron username "$neutron_admin_user"
iniset_sudo $conf neutron password "$NEUTRON_PASS"
iniset_sudo $conf neutron service_metadata_proxy true
iniset_sudo $conf neutron metadata_proxy_shared_secret "$METADATA_SECRET"

echo "Creating Link in /etc/neutron/ for ml2_conf.ini as plugin.ini. "
sudo ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Configuring neutron for controller node."
function get_database_url {
    local db_user=$NEUTRON_DB_USER
    local database_host=controller

    echo "mysql+pymysql://$db_user:$NEUTRON_DBPASS@$database_host/neutron"
}

database_url=$(get_database_url)

neutron_admin_user=neutron

nova_admin_user=nova

echo "Setting database connection: $database_url."
conf=/etc/neutron/neutron.conf

# Configure [database] section.
iniset_sudo $conf database connection "$database_url"

# Configure [DEFAULT] section.
iniset_sudo $conf DEFAULT core_plugin ml2
iniset_sudo $conf DEFAULT service_plugins router
iniset_sudo $conf DEFAULT allow_overlapping_ips true

echo "Configuring RabbitMQ message queue access."
iniset_sudo $conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller"

iniset_sudo $conf DEFAULT auth_strategy keystone

# Configuring [keystone_authtoken] section.
iniset_sudo $conf keystone_authtoken www_authenticate_uri http://controller:5000
iniset_sudo $conf keystone_authtoken auth_url http://controller:5000
iniset_sudo $conf keystone_authtoken memcached_servers controller:11211
iniset_sudo $conf keystone_authtoken auth_type password
iniset_sudo $conf keystone_authtoken project_domain_name default
iniset_sudo $conf keystone_authtoken user_domain_name default
iniset_sudo $conf keystone_authtoken project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf keystone_authtoken username "$neutron_admin_user"
iniset_sudo $conf keystone_authtoken password "$NEUTRON_PASS"

# Configure nova related parameters
iniset_sudo $conf DEFAULT notify_nova_on_port_status_changes true
iniset_sudo $conf DEFAULT notify_nova_on_port_data_changes true

# Configure [nova] section.
iniset_sudo $conf nova auth_url http://controller:5000
iniset_sudo $conf nova auth_type password
iniset_sudo $conf nova project_domain_name default
iniset_sudo $conf nova user_domain_name default
iniset_sudo $conf nova region_name "$REGION"
iniset_sudo $conf nova project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf nova username "$nova_admin_user"
iniset_sudo $conf nova password "$NOVA_PASS"

# Configure [experimental] section. Added in Openstack Zed
iniset_sudo $conf experimental linuxbridge true

# lock_path, not in install-guide:
iniset_sudo $conf oslo_concurrency lock_path /var/lib/neutron/tmp

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure the Modular Layer 2 (ML2) plug-in
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Configuring the Modular Layer 2 (ML2) plug-in."
conf=/etc/neutron/plugins/ml2/ml2_conf.ini

# Edit the [ml2] section.
iniset_sudo $conf ml2 type_drivers flat,vlan,vxlan
iniset_sudo $conf ml2 tenant_network_types vxlan
iniset_sudo $conf ml2 mechanism_drivers linuxbridge,l2population
iniset_sudo $conf ml2 extension_drivers port_security

# Edit the [ml2_type_flat] section.
iniset_sudo $conf ml2_type_flat flat_networks provider

iniset_sudo $conf ml2_type_vxlan vni_ranges 1:1000

# Edit the [securitygroup] section.
iniset_sudo $conf securitygroup enable_ipset true


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure the layer-3 agent
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Configuring the layer-3 agent."
conf=/etc/neutron/l3_agent.ini
iniset_sudo $conf DEFAULT interface_driver linuxbridge

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure the DHCP agent
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Configuring the DHCP agent."
conf=/etc/neutron/dhcp_agent.ini
iniset_sudo $conf DEFAULT interface_driver linuxbridge
iniset_sudo $conf DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
iniset_sudo $conf DEFAULT enable_isolated_metadata true

echo "Populating the database."
sudo neutron-db-manage \
    --config-file /etc/neutron/neutron.conf \
    --config-file /etc/neutron/plugins/ml2/ml2_conf.ini \
    upgrade head


sudo firewall-cmd --add-port=9696/tcp --permanent
sudo firewall-cmd --reload

sudo touch linuxbridgectl.te

cat <<EOF | sudo tee -a linuxbridgectl.te

module linuxbridgectl 1.0;

require {
        type neutron_t;
        type neutron_exec_t;
        type neutron_t;
        type dnsmasq_t;
        class file execute_no_trans;
        class capability { dac_override sys_rawio };
}

#============= neutron_t ==============
allow neutron_t self:capability { dac_override sys_rawio };
allow neutron_t neutron_exec_t:file execute_no_trans;

#============= dnsmasq_t ==============
allow dnsmasq_t self:capability dac_override;

EOF

sudo checkmodule -m -M -o linuxbridgectl.mod linuxbridgectl.te
sudo semodule_package --outfile linuxbridgectl.pp --module linuxbridgectl.mod
sudo semodule -i linuxbridgectl.pp

sudo setsebool -P neutron_can_network on
sudo setsebool -P haproxy_connect_any on
sudo setsebool -P daemons_enable_cluster_mode on


echo "Restarting nova services."
sudo systemctl restart openstack-nova-api

echo "Restarting neutron-server."
sudo systemctl restart neutron-server && sudo systemctl enable neutron-server

echo "Restarting neutron-dhcp-agent."
sudo systemctl restart neutron-dhcp-agent && sudo systemctl enable neutron-dhcp-agent

echo "Restarting neutron-metadata-agent."
sudo systemctl restart neutron-metadata-agent && sudo systemctl enable neutron-metadata-agent

if type neutron-l3-agent; then
    echo "Restarting neutron-l3-agent."
    sudo systemctl restart neutron-l3-agent && sudo systemctl enable neutron-l3-agent
fi

#------------------------------------------------------------------------------
# Set up OpenStack Networking (neutron) for controller node.
#------------------------------------------------------------------------------

echo -n "Verifying operation."
until openstack network agent list >/dev/null 2>&1; do
    sleep 1
    echo -n .
done
echo

openstack network agent list
