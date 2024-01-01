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


#------------------------------------------------------------------------------
# Dwnloading Image for Ubuntu 22.04 
#------------------------------------------------------------------------------

echo "Dwnloading Image for Ubuntu 22.04"
echo
if [ ! -f 'trove-master-guest-ubuntu-jammy.qcow2' ]
then
	wget https://tarballs.opendev.org/openstack/trove/images/trove-master-guest-ubuntu-jammy.qcow2
fi
#------------------------------------------------------------------------------
# Creating Trove-Ubuntu openstack Image from the downloaded file
#------------------------------------------------------------------------------

echo
echo "Creating Trove-Ubuntu openstack Image from the downloaded file.."
echo 

openstack image create Trove-Ubuntu --file=trove-master-guest-ubuntu-jammy.qcow2 --disk-format=qcow2 --container-format=bare --tag=trove --public

sudo rm -rf trove-master-guest-ubuntu-jammy.qcow2

#------------------------------------------------------------------------------
# Adding MariaDB, MySQL and PostgreSQL to the Datastore
#------------------------------------------------------------------------------

echo "Sourcing the admin credentials."
source "$CONFIG_DIR/admin-openstackrc.sh"

sudo su -s /bin/bash -c "trove-manage datastore_update mariadb ''" trove
sudo su -s /bin/bash -c "trove-manage datastore_update mysql ''" trove
sudo su -s /bin/bash -c "trove-manage datastore_update postgresql ''" trove

#------------------------------------------------------------------------------
# Updating Trove Database for Multiple Versions of MariaDB, MySQL and PostgreSQL
#------------------------------------------------------------------------------

echo
echo "Getting Image ID for the Databases"
echo

imgID=$(openstack image list | grep 'Trove' | awk '{print $2}')

echo "The Image ID is $imgID"
echo

echo "Updating Trove Database for Multiple Versions of MariaDB, MySQL and PostgreSQL"
echo

sudo su -s /bin/sh trove -c "trove-manage datastore_version_update mariadb 10.2 mariadb $imgID mariadb 1"
sudo su -s /bin/sh trove -c "trove-manage datastore_version_update mariadb 10.3 mariadb $imgID mariadb 1"
sudo su -s /bin/sh trove -c "trove-manage datastore_version_update mariadb 10.6 mariadb $imgID mariadb 1"
sudo su -s /bin/sh trove -c "trove-manage datastore_version_update mysql 5.7 mysql $imgID mysql 1"
sudo su -s /bin/sh trove -c "trove-manage datastore_version_update mysql 8.0 mysql $imgID mysql 1"
sudo su -s /bin/sh trove -c "trove-manage datastore_version_update postgresql 10 postgresql $imgID postgresql 1"
sudo su -s /bin/sh trove -c "trove-manage datastore_version_update postgresql 12 postgresql $imgID postgresql 1"

#------------------------------------------------------------------------------
# Setting Database Options for Multiple Versions of MariaDB, MySQL and PostgreSQL
#------------------------------------------------------------------------------

# Setting Database Options for Multiple Versions of MariaDB, MySQL and PostgreSQL
sudo su -s /bin/bash trove -c "trove-manage db_load_datastore_config_parameters mariadb 10.2 /usr/lib/python3/dist-packages/trove/templates/mariadb/validation-rules.json"
sudo su -s /bin/bash trove -c "trove-manage db_load_datastore_config_parameters mariadb 10.3 /usr/lib/python3/dist-packages/trove/templates/mariadb/validation-rules.json"
sudo su -s /bin/bash trove -c "trove-manage db_load_datastore_config_parameters mariadb 10.6 /usr/lib/python3/dist-packages/trove/templates/mariadb/validation-rules.json"
sudo su -s /bin/bash trove -c "trove-manage db_load_datastore_config_parameters mysql 5.7 /usr/lib/python3/dist-packages/trove/templates/mysql/validation-rules.json"
sudo su -s /bin/bash trove -c "trove-manage db_load_datastore_config_parameters mysql 8.0 /usr/lib/python3/dist-packages/trove/templates/mysql/validation-rules.json"
sudo su -s /bin/bash trove -c "trove-manage db_load_datastore_config_parameters postgresql 10 /usr/lib/python3/dist-packages/trove/templates/postgresql/validation-rules.json"
sudo su -s /bin/bash trove -c "trove-manage db_load_datastore_config_parameters postgresql 12 /usr/lib/python3/dist-packages/trove/templates/postgresql/validation-rules.json"

#------------------------------------------------------------------------------
# Verifying Databases in the Datastore of Trove
#------------------------------------------------------------------------------

# Verifying Databases in the Datastore of Trove
openstack datastore list

#------------------------------------------------------------------------------
# Verifying Database Versions for  MariaDB, MySQL and PostgreSQL
#------------------------------------------------------------------------------

# Verifying Database Versions for  MariaDB, MySQL and PostgreSQL
echo "Verifying Database Versions for  MariaDB, MySQL and PostgreSQL"
echo "MariaDB.."

openstack datastore version list mariadb

echo "Verifying Database Versions for MySQL"
echo "MySQL.."

openstack datastore version list mysql
echo "Verifying Database Versions for  PostgreSQL"
echo "PostgresSQL.."

openstack datastore version list postgresql

echo "Script Execution Completed Successfully!"
