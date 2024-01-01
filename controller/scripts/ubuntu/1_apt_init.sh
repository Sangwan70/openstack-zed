#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/openstack"
source "$CONFIG_DIR/localrc"
source "$LIB_DIR/functions.guest.sh"

indicate_current_auto

exec_logfile

function set_apt_proxy {
    local PRX_KEY="Acquire::http::Proxy"
    local APT_FILE=/etc/apt/apt.conf

    if [ -f $APT_FILE ] && grep -q $PRX_KEY $APT_FILE; then
        # apt proxy has already been set (by preseed/kickstart)
        if [ -n "${VM_PROXY-}" ]; then
            # Replace with requested proxy
            sudo sed -i "s#^\($PRX_KEY\).*#\1 \"$VM_PROXY\";#" $APT_FILE
        else
            # No proxy requested -- remove
            sudo sed -i "s#^$PRX_KEY.*##" $APT_FILE
        fi
    elif [ -n "${VM_PROXY-}" ]; then
        # Proxy requested, but none configured: add line
        echo "$PRX_KEY \"$VM_PROXY\";" | sudo tee -a $APT_FILE
    fi
}

set_apt_proxy

# Use repository redirection for faster repository access.
# instead of the 'us.archive.ubuntu.com' ones in United States
sudo sed  -i 's/us.archive.ubuntu.com/archive.ubuntu.com/g' /etc/apt/sources.list

# Get apt index files
sudo apt update

# ---------------------------------------------------------------------------
# Enable the OpenStack repository
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#--------------------------------------------------------------------------

echo "Installing packages needed for add-apt-repository."
sudo apt -y install software-properties-common

case "$OPENSTACK_RELEASE" in
    bobcat)
        REPO=cloud-archive:bobcat
        SRC_FILE=cloudarchive-bobcat.list
        ;;
    caracal)
        REPO=cloud-archive:caracal
        SRC_FILE=cloudarchive-caracal.list
        ;;
    zed)
        REPO=cloud-archive:zed
        SRC_FILE=cloudarchive-zed.list
        ;;
    *)
        echo >&2 "Unknown OpenStack release: $OPENSTACK_RELEASE. Aborting."
        exit 1
        ;;
esac

echo "Adding cloud repo: $REPO"
sudo add-apt-repository "$REPO"

# Get index files only for ubuntu-cloud repo but keep standard lists
if [ -f "/etc/apt/sources.list.d/$SRC_FILE" ]; then
    sudo apt update \
        -o Dir::Etc::sourcelist="sources.list.d/$SRC_FILE" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
else
    echo "ERROR: apt source not found: /etc/apt/sources.list.d/$SRC_FILE"
    exit 1
fi

# Disable automatic updates
sudo systemctl disable apt-daily.service
sudo systemctl disable apt-daily.timer

# ---------------------------------------------------------------------------
# Install mariadb-server from upstream repo (mariadb 10.5 shipping)
# ---------------------------------------------------------------------------

# Add mariadb repo
cat << EOF | sudo tee /etc/apt/sources.list.d/mariadb.list
deb http://mariadb.mirror.globo.tech/repo/10.5/ubuntu focal main 
EOF

# Import key required for mariadb
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' 

# Update apt database for mariadb repo
sudo apt update \
    -o Dir::Etc::sourcelist="sources.list.d/mariadb.list" \
    -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

# Pre-configure database root password in /var/cache/debconf/passwords.dat

source "$CONFIG_DIR/credentials"
echo "mysql-server mysql-server/root_password password $DATABASE_PASSWORD" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DATABASE_PASSWORD" | sudo debconf-set-selections
