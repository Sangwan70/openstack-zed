#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)
source "$TOP_DIR/config/paths"
source "$LIB_DIR/functions.guest.sh"

source "$CONFIG_DIR/credentials"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Prerequisites
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "Installing barbican packages."
sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall barbican-common barbican-api barbican-worker barbican-keystone-listener

cd ~
git clone https://github.com/openstack/barbican-ui

sudo pip3 install -e barbican-ui/

sudo cp -r barbican-ui/barbican_ui/ /usr/local/lib/python3.10/dist-packages/
sudo sed -i "s/url(''/url('secrets'/g" /usr/local/lib/python3.10/dist-packages/barbican_ui/content/secrets/urls.py

sudo cp /usr/local/lib/python3.10/dist-packages/barbican_ui/enabled/_9?*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/

sudo sudo sed -i "s/from django.utils.translation import ugettext_lazy as _/from django.conf import settings\\nfrom django.utils.translation import gettext_lazy as _\\nimport horizon/g" \
/usr/share/openstack-dashboard/openstack_dashboard/local/enabled/_90_barbican_barbican_panelgroup.py


sudo tee -a /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/_90_barbican_barbican_panelgroup.py > /dev/null <<END
class BarbicanUI(horizon.Dashboard):
    name = getattr(settings, 'BARBICAN_DASHBOARD_NAME', _("Barbican"))
    slug = "barbican"
    default_panel = "secrets"
    supports_tenants = True


try:
    horizon.base.Horizon.registered('barbican')
except horizon.base.NotRegistered:
    horizon.register(BarbicanUI)
END

cd /usr/share/openstack-dashboard
sudo python3 manage.py compress

