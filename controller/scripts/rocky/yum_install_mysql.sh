#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#-------------------------------------------------------------------------------
# Controller setup
#-------------------------------------------------------------------------------


DB_IP=$(get_node_ip_in_network "$(hostname)" "mgmt")
echo "Will bind MariaDB server to $DB_IP."

#------------------------------------------------------------------------------
# Install and configure the database server
#------------------------------------------------------------------------------

echo "Sourced MariaDB password from credentials: $DATABASE_PASSWORD"


echo "Installing MariaDB ."
sudo yum install -y mariadb-server mariadb python3-PyMySQL

echo "Restarting MariaDB service."
sudo systemctl restart mariadb.service 2>/dev/null
sudo systemctl enable mariadb.service 2>/dev/null

# Not in install-guide
# To drop socket auth for root user and use root password:
sudo mysql -u "root" -e "ALTER USER root@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$DATABASE_PASSWORD'); FLUSH PRIVILEGES;"

# Not in the install-guide
echo "Sanity check: check if password login works for root."
sudo mysql -u root -p"$DATABASE_PASSWORD" -e quit

conf=/etc/my.cnf.d/99-openstack.cnf

echo "Creating $conf."
echo '[mysqld]' | sudo tee $conf

echo "Configuring MariaDB to accept requests from management network ($DB_IP)."
iniset_sudo $conf mysqld bind-address "$DB_IP"

iniset_sudo $conf mysqld default-storage-engine innodb
iniset_sudo $conf mysqld innodb_file_per_table on
iniset_sudo $conf mysqld max_connections 4096
iniset_sudo $conf mysqld collation-server utf8_general_ci
iniset_sudo $conf mysqld character-set-server utf8

echo "Restarting MariaDB service."
# Close the file descriptor or the script will hang due to open ssh connection
sudo systemctl restart mariadb.service 2>/dev/null
sudo systemctl enable mariadb.service 2>/dev/null

echo "Enabling Firewall Service."
sudo firewall-cmd --permanent --add-service=mysql 
sudo firewall-cmd --reload
