#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#------------------------------------------------------------------------------
# Set up OpenStack Dashboard (horizon)
#------------------------------------------------------------------------------

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install and configure components
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Note: Installing the dashboard here reloads the apache configuration.
#       Below, we are also changing the configuration and reloading it once we
#       are done. This race can result in a stopped apache (which also means
#       stopped keystone services). 

echo "Installing horizon Dashboard"
sudo dnf install -y openstack-dashboard python3-heatclient

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Edit the /etc/openstack-dashboard/local_settings file.
conf=/etc/openstack-dashboard/local_settings
auth_host=controller

echo "Setting OPENSTACK_HOST = \"$auth_host\"."
iniset_sudo_no_section $conf "OPENSTACK_HOST" "\"$auth_host\""

echo "Allowing all hosts to access the dashboard:"
iniset_sudo_no_section $conf "ALLOWED_HOSTS" "['*', ]"

echo "Telling horizon to use the cache for sessions."
iniset_sudo_no_section $conf "SESSION_ENGINE" "'django.contrib.sessions.backends.cache'"

echo "Setting interface location of memcached."
sudo sed -i "/LOCATION/ s/127.0.0.1/controller/" $conf
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Comparing $conf to memcached"
memcached_conf=/etc/sysconfig/memcached

# Port is a number on line starting with "-p "
port=$(grep -Po -- '[0-9]{5}' $memcached_conf)

# Interface is an IP address on line starting with "-l "
interface_ip=$(grep -Po -- '([0-9]{1,3}\.){3}[0-9]{1,3}' $memcached_conf)

echo "memcached listening on $interface_ip:$port."

# Turn IP address into corresponding host name
interface_name=$(getent hosts "$auth_host" | awk '{ print $2 }')

# Line should read something like: 'LOCATION' : 'controller:11211',
if sudo grep "LOCATION.*$interface_name:$port" $conf; then
    echo "$conf agrees."
else
    echo >&2 "$conf disagrees. Aborting."
    exit 1
fi

echo "CACHES configuration in $conf:"
sudo awk '/^CACHES =/,/^}/' $conf
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Enabling Identity API version 3."
iniset_sudo_no_section $conf "OPENSTACK_KEYSTONE_URL" '"http://%s:5000/v3" % OPENSTACK_HOST'

echo "Enabling support for domains."
iniset_sudo_no_section $conf "OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT" True

cat << API | sudo tee -a $conf

WEBROOT = '/dashboard/'
LOGIN_URL = '/dashboard/auth/login/'
LOGOUT_URL = '/dashboard/auth/logout/'
LOGIN_REDIRECT_URL = '/dashboard/'

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': 'controller:11211',
    },
}

# Use Keystone V3 API for dashboard login.
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}
API

echo "Configuring 'default' as the default domain for users created via " \
    "dashboard."
iniset_sudo_no_section $conf "OPENSTACK_KEYSTONE_DEFAULT_DOMAIN" '"Default"'

echo "Configuring 'user' as the default role for users created via dashboard."
iniset_sudo_no_section $conf "OPENSTACK_KEYSTONE_DEFAULT_ROLE" '"user"'

# Here, we would disable layer-3 networking servies for networking option 1.

echo "Setting timezone to Asia/Kolkata."
iniset_sudo_no_section $conf "TIME_ZONE" '"Asia/Kolkata"'

echo "Verifying presence of 'WSGIApplicationGroup %{GLOBAL}'."
conf=/etc/httpd/conf.d/openstack-dashboard.conf
sudo sed -i '/^WSGISocketPrefix.*/a WSGIApplicationGroup %{GLOBAL}' $conf


sudo grep "WSGIApplicationGroup %{GLOBAL}" $conf

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Customize Horizon Dashboard (not in install-guide)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Reduce memory usage (not in install-guide)
conf=/etc/httpd/conf.d/openstack-dashboard.conf
sudo sed -i --follow-symlinks '/WSGIDaemonProcess/ s/processes=[0-9]*/processes=1/' $conf
sudo sed -i --follow-symlinks '/WSGIDaemonProcess/ s/threads=[0-9]*/threads=2/' $conf
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# if [ -d "/usr/share/openstack-dashboard/openstack_dashboard" ] 
# then
#     sudo cp /home/stack/django.wsgi /usr/share/openstack-dashboard/openstack_dashboard/wsgi/
# else
#     sudo mkdir /usr/share/openstack-dashboard/openstack_dashboard/wsgi/
#    sudo cp /home/stack/django.wsgi /usr/share/openstack-dashboard/openstack_dashboard/wsgi/
# fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finalize installation
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Reloading the web server configuration."
# Restarting instead of reloading for reasons explained in comment above.
sudo systemctl restart httpd
sudo systemctl enable httpd
sudo systemctl status httpd

sudo firewall-cmd --permanent --add-service={http,https} 
sudo firewall-cmd --reload
