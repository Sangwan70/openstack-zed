sudo semodule -r novaapi
sudo semodule -r linuxbridgectl
sudo semodule -r ovsofctl

sudo semanage port -d -p tcp 8778

sudo firewall-cmd --permanent --remove-service={http,https,mysql}
sudo firewall-cmd --permanent --remove-port={11211,8000,8004,8041,5672,5000,9191,9292,9311,6080,6081,6082,8774,8775,8778,8776,9696}/tcp
sudo firewall-cmd --reload

sudo yum erase -y python3-openstackclient memcached python3-memcached  \
	openstack-neutron openstack-neutron-ml2 \
	openstack-nova-api openstack-nova-conductor openstack-nova-novncproxy openstack-nova-scheduler \
	openstack-neutron-linuxbridge openstack-cinder openstack-placement-api openstack-dashboard openstack-heat-common \
	openstack-heat-api openstack-heat-api-cfn openstack-heat-engine
sudo yum erase -y openstack-swift-proxy python3-swift python3-swiftclient rdo-release \
        python3-keystoneclient python3-keystonemiddleware

sudo yum erase -y openstack-selinux python3-openstacksdk

sudo rm -rf /etc/cinder/ /etc/glance/ /etc/httpd/ /etc/keystone/ /etc/my.cnf.d/ /etc/neutron/ /etc/nova/ /var/lib/cinder/ \
	/var/lib/httpd/ /var/lib/keystone/ /var/lib/mysql/ /var/lib/glance/ /var/lib/nova/ /var/lib/openstack-dashboard/ \
	/var/lib/neutron/ /etc/placement/ /etc/rabbitmq/ /var/lib/openvswitch/ /var/lib/rabbitmq/ /etc/sysconfig/openstack-nova-novncproxy \
	/etc/swift/ /var/log/swift/ /etc/sysconfig/memcached /home/stack/scripts/rocky/*.{mod,pp,te}

sudo rm -rf /home/stack/log/* /etc/ceilometer /etc/barbican /etc/gnocchi /etc/heat /var/log/glance /var/log/gnocchi /var/log/heat \
	   /var/log/neutron /var/log/nova /var/log/placement /var/log/rabbitmq  /var/log/cinder /var/log/ceilometer /var/log/httpd \
	   /var/log/mariadb

sudo rm -rf /var/lib/swift /var/lib/gnocchi /var/lib/heat /var/lib/ceilometer /var/lib/barbican /tmp/*  /etc/openstack-dashboard/ /etc/openvswitch/
sudo rm -rf /var/log/*.lsl
sudo sed -i "s/^net.*$//g" /etc/sysctl.conf

