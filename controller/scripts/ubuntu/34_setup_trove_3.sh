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

TROVE_VOL=trove-volume
#------------------------------------------------------------------------------
# Install the Database Service (trove)
#------------------------------------------------------------------------------

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openstackrc.sh"

#------------------------------------------------------------------------------
# Creating openstack volume type needed for Trove
#------------------------------------------------------------------------------

echo
echo "Creating openstack volume type needed.."
echo

if [ $(openstack volume type list | grep 'trove' | awk '{print $4}') == "$TROVE_VOL" ]
then 
  echo "Openstack Volume type already exists. Continuing"
else
  openstack volume type create $TROVE_VOL --public
fi


trove_admin_user=trove

# Wait for keystone to come up
wait_for_keystone

function get_database_url {
    local db_user=$TROVE_DB_USER
    local database_host=controller

    echo "mysql+pymysql://$db_user:$TROVE_DBPASS@$database_host/trove"
}

database_url=$(get_database_url)
echo "Database connection: $database_url."

echo "Configuring trove.conf."
conf=/etc/trove/trove.conf
iniset_sudo $conf database connection "$database_url"


echo "Configuring RabbitMQ message queue access."
iniset_sudo $conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller"
iniset_sudo $conf DEFAULT network_driver trove.network.neutron.NeutronDriver
iniset_sudo $conf DEFAULT cinder_volume_type $TROVE_VOL
iniset_sudo $conf DEFAULT default_datastore mysql
iniset_sudo $conf DEFAULT nova_keypair trove-mgmt
iniset_sudo $conf DEFAULT taskmanager_manager trove.taskmanager.manager.Manager
iniset_sudo $conf DEFAULT trove_api_workers 5
iniset_sudo $conf DEFAULT control_exchange trove
iniset_sudo $conf DEFAULT reboot_time_out 300
iniset_sudo $conf DEFAULT usage_timeout 900
iniset_sudo $conf DEFAULT agent_call_high_timeout 1200
iniset_sudo $conf DEFAULT  use_syslog False


echo "Configuring keystone."
# Configure [keystone_authtoken] section.
iniset_sudo $conf keystone_authtoken www_authenticate_uri http://controller:5000
iniset_sudo $conf keystone_authtoken auth_url http://controller:5000
iniset_sudo $conf keystone_authtoken memcached_servers controller:11211
iniset_sudo $conf keystone_authtoken auth_type password
iniset_sudo $conf keystone_authtoken project_domain_name default
iniset_sudo $conf keystone_authtoken user_domain_name default
iniset_sudo $conf keystone_authtoken project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf keystone_authtoken username "$trove_admin_user"
iniset_sudo $conf keystone_authtoken password "$TROVE_PASS"

iniset_sudo $conf service_credentials auth_url http://controller:5000
iniset_sudo $conf service_credentials region_name RegionOne
iniset_sudo $conf service_credentials project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf service_credentials password "$TROVE_PASS"
iniset_sudo $conf service_credentials project_domain_name default
iniset_sudo $conf service_credentials user_domain_name default
iniset_sudo $conf service_credentials username "$trove_admin_user"

iniset_sudo $conf mariadb tcp_ports "3306,4444,4567,4568"

iniset_sudo $conf mysql tcp_ports 3306

iniset_sudo $conf postgresql tcp_ports 5432


conf=/etc/trove/trove-guestagent.conf

iniset_sudo $conf DEFAULT log_dir /var/log/trove
iniset_sudo $conf DEFAULT log_file trove-guestagent.log
iniset_sudo $conf DEFAULT ignore_users os_admin
iniset_sudo $conf DEFAULT control_exchange trove
iniset_sudo $conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller"
iniset_sudo $conf DEFAULT command_process_timeout 60
iniset_sudo $conf DEFAULT use_syslog False

iniset_sudo $conf service_credentials auth_url http://controller:5000
iniset_sudo $conf service_credentials region_name RegionOne
iniset_sudo $conf service_credentials project_domain_name default
iniset_sudo $conf service_credentials user_domain_name default
iniset_sudo $conf service_credentials project_name "$SERVICE_PROJECT_NAME"
iniset_sudo $conf service_credentials username "$trove_admin_user"
iniset_sudo $conf service_credentials password "$TROVE_PASS"

sudo chmod 640 /etc/trove/
sudo chgrp trove /etc/trove/


echo "Creating the database tables for trove."
sudo su -s /bin/bash -c "trove-manage db_sync"


echo "Creating the Cloud Init Scripts"

CLOUDINIT="/etc/trove/cloudinit/"
if [ ! -d "$CLOUDINIT" ]
then
sudo rm -rf "$CLOUDINIT" 
fi

sudo mkdir $CLOUDINIT
cat << CINIT | sudo tee -a $CLOUDINIT/mariadb.cloudinit
# Use Keystone V3 API for dashboard login.
runcmd:
  - echo 'CONTROLLER=controller' > /etc/trove/controller.conf
  - chmod 664 /etc/trove/controller.conf
CINIT


sudo cp /etc/trove/cloudinit/mariadb.cloudinit /etc/trove/cloudinit/postgresql.cloudinit
sudo cp /etc/trove/cloudinit/mariadb.cloudinit /etc/trove/cloudinit/mysql.cloudinit

sudo chgrp -R trove /etc/trove/
sudo chmod 775 -R /etc/trove/

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Restarting trove services."
STARTTIME=$(date +%s)
sudo systemctl restart trove-api trove-taskmanager trove-conductor
sudo systemctl enable trove-api trove-taskmanager trove-conductor
sudo systemctl status trove-api trove-taskmanager trove-conductor

sudo systemctl restart apache2

echo -n "Waiting for openstack datastore list."
source ~/admin-openrc.sh
until openstack datastore list; do
    sleep 1
    echo -n .
done
ENDTIME=$(date +%s)
echo "Restarting trove servies took $((ENDTIME - STARTTIME)) seconds."

