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
# Networking Option 2: Self-service networks
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install the components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing additional packages for self-service networks."
sudo dnf install -y openstack-neutron-linuxbridge

echo "Configuring Linux Bridge agent."
conf=/etc/neutron/plugins/ml2/linuxbridge_agent.ini

# Edit the [linux_bridge] section.
set_iface_list
PUBLIC_INTERFACE_NAME=$(ifnum_to_ifname 2)
echo "PUBLIC_INTERFACE_NAME=$PUBLIC_INTERFACE_NAME"
iniset_sudo $conf linux_bridge physical_interface_mappings provider:$PUBLIC_INTERFACE_NAME

# Edit the [vxlan] section.
OVERLAY_INTERFACE_IP_ADDRESS=$(get_node_ip_in_network "$(hostname)" "mgmt")
iniset_sudo $conf vxlan enable_vxlan true
iniset_sudo $conf vxlan local_ip $OVERLAY_INTERFACE_IP_ADDRESS
iniset_sudo $conf vxlan l2_population true

# Edit the [securitygroup] section.
iniset_sudo $conf securitygroup enable_security_group true
iniset_sudo $conf securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

conf=/etc/sysctl.d/99-sysctl.conf
sudo touch $conf
iniset_sudo_no_section $conf net.bridge.bridge-nf-call-iptables 1
iniset_sudo_no_section $conf net.bridge.bridge-nf-call-ip6tables 1

echo "Ensuring that the kernel supports network bridge filters."
if ! sysctl net.bridge.bridge-nf-call-iptables; then
    sudo modprobe br_netfilter
    sudo echo '1' > sudo /proc/sys/net/bridge/bridge-nf-call-iptables
    sudo sysctl -p
fi

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

echo "Restarting neutron-linuxbridge-agent."
sudo systemctl restart neutron-linuxbridge-agent && sudo systemctl enable neutron-linuxbridge-agent

# Not in install-guide:
iniset_sudo_no_section $conf dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf

cat << DNSMASQ | sudo tee /etc/neutron/dnsmasq-neutron.conf
# Override --no-hosts dnsmasq option supplied by neutron
addn-hosts=/etc/hosts

# Log dnsmasq queries to syslog
log-queries

# Verbose logging for DHCP
log-dhcp
DNSMASQ
echo "Executing of the script completed successfully"
echo 
