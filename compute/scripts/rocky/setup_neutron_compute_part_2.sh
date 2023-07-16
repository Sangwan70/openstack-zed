#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"
source "$CONFIG_DIR/openstack"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Install and configure compute node
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Configure the Compute service to use the Networking service
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

neutron_admin_user=neutron

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

# Configure [experimental] section. Added in Openstack Zed
iniset_sudo $conf experimental linuxbridge true


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Restarting the Compute service."
sudo systemctl restart openstack-nova-compute

echo "Restarting neutron-linuxbridge-agent."
sudo systemctl restart neutron-linuxbridge-agent
sudo systemctl enable neutron-linuxbridge-agent
sudo systemctl status neutron-linuxbridge-agent.service

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Enable Firewall and SELinux
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Networking Option 2: Self-service networks
#------------------------------------------------------------------------------

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openstackrc.sh"

echo "Listing agents to verify successful launch of the neutron agents."

echo "openstack network agent list"
openstack network agent list
