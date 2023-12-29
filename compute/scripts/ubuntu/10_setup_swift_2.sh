#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"
source "$CONFIG_DIR/admin-openstackrc.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Install and configure a storage node
#------------------------------------------------------------------------------

MY_MGMT_IP=$(get_node_ip_in_network "$(hostname)" "mgmt")
echo "IP address of this node's interface in management network: $MY_MGMT_IP."

# echo "Configuring Disks for swift Object Storage."

swift_dev1=sdb
swift_dev2=sdc

sudo mkfs.xfs -f /dev/$swift_dev1
sudo mkfs.xfs -f /dev/$swift_dev2

sudo mkdir -p /srv/node/$swift_dev1
sudo mkdir -p /srv/node/$swift_dev2

# echo "Making Entries into /ets/fstab to make the devices available on reboot"

conf=/etc/fstab

cat << FSTAB | sudo tee -a $conf
/dev/sdb /srv/node/sdb xfs noatime 0 2
/dev/sdc /srv/node/sdc xfs noatime 0 2
FSTAB

sudo mount /dev/$swift_dev1 /srv/node/$swift_dev1
sudo mount /dev/$swift_dev2 /srv/node/$swift_dev2

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create or edit the /etc/rsyncd.conf file
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sudo touch /etc/rsyncd.conf
conf=/etc/rsyncd.conf

iniset_sudo_no_section $conf uid swift
iniset_sudo_no_section $conf gid swift
iniset_sudo_no_section $conf address $MY_MGMT_IP

iniset_sudo $conf object path /srv/node/

sudo touch /etc/default/rsync

conf=/etc/default/rsync
iniset_sudo_no_section $conf RSYNC_ENABLE true 

echo "start the rsync service."
sudo systemctl enable rsync.service
sudo systemctl start rsync.service
sudo systemctl status rsync.service

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Obtain the configuration files from the Object Storage source repository.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sudo mkdir -p /etc/swift

sudo curl -o /etc/swift/account-server.conf https://opendev.org/openstack/swift/raw/branch/stable/zed/etc/account-server.conf-sample
sudo curl -o /etc/swift/container-server.conf https://opendev.org/openstack/swift/raw/branch/stable/zed/etc/container-server.conf-sample
sudo curl -o /etc/swift/object-server.conf https://opendev.org/openstack/swift/raw/branch/stable/zed/etc/object-server.conf-sample

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Edit the /etc/swift/account-server.conf file.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

conf=/etc/swift/account-server.conf

iniset_sudo $conf DEFAULT bind_ip $MY_MGMT_IP
iniset_sudo $conf DEFAULT bind_port 6202
iniset_sudo $conf DEFAULT user swift
iniset_sudo $conf DEFAULT swift_dir /etc/swift
iniset_sudo $conf DEFAULT devices /srv/node
iniset_sudo $conf DEFAULT mount_check True
iniset_sudo $conf pipeline:main pipeline "healthcheck recon account-server"
iniset_sudo $conf filter:recon use egg:swift#recon
iniset_sudo $conf filter:recon recon_cache_path /var/cache/swift


conf=/etc/swift/container-server.conf

iniset_sudo $conf DEFAULT bind_ip $MY_MGMT_IP
iniset_sudo $conf DEFAULT bind_port 6201
iniset_sudo $conf DEFAULT user swift
iniset_sudo $conf DEFAULT swift_dir /etc/swift
iniset_sudo $conf DEFAULT devices /srv/node
iniset_sudo $conf DEFAULT mount_check True
iniset_sudo $conf pipeline:main pipeline "healthcheck recon container-server"
iniset_sudo $conf filter:recon use egg:swift#recon
iniset_sudo $conf filter:recon recon_cache_path /var/cache/swift


conf=/etc/swift/object-server.conf

iniset_sudo $conf DEFAULT bind_ip $MY_MGMT_IP
iniset_sudo $conf DEFAULT bind_port 6200
iniset_sudo $conf DEFAULT user swift
iniset_sudo $conf DEFAULT swift_dir /etc/swift
iniset_sudo $conf DEFAULT devices /srv/node
iniset_sudo $conf DEFAULT mount_check True
iniset_sudo $conf pipeline:main pipeline "healthcheck recon object-server"
iniset_sudo $conf filter:recon use egg:swift#recon
iniset_sudo $conf filter:recon recon_cache_path /var/cache/swift
iniset_sudo $conf filter:recon recon_lock_path /var/lock


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Ensure proper ownership of the mount point directory structure:
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sudo chown -R swift:swift /srv/node

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create the recon directory and ensure proper ownership of it:
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sudo mkdir -p /var/cache/swift
sudo chown -R root:swift /var/cache/swift
sudo chmod -R 775 /var/cache/swift
