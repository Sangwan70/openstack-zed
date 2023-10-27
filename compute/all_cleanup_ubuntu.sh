sudo apt remove -y --purge barbican-api
sudo apt remove -y --purge git
sudo apt remove -y --purge python3-pip virtualenv python3-openstackclient cinder-api cinder-scheduler
sudo apt remove -y --purge python3-openstackclient
sudo apt remove -y --purge cinder-api cinder-scheduler
sudo apt remove -y --purge cinder-scheduler
sudo apt remove -y --purge placement-api
sudo apt remove -y --purge swift
sudo apt remove -y --purge swift-account
sudo apt remove -y --purge python3-swift python3-swiftclient nova-api nova-conductor nova-novncproxy nova-scheduler
sudo apt remove -y --purge barbican-api barbican-worker barbican-keystone-listener
sudo apt remove -y --purge python-networking-sfc python3-openstackclient cinder-api cinder-scheduler
sudo apt remove -y --purge placement-api python3-pip swift swift-account swift-container swift-object xfsprogs
sudo apt remove -y --purge python3-swift python3-swiftclient nova-api nova-conductor nova-novncproxy nova-scheduler

sudo rm -rf /etc/cinder/ /etc/neutron/ /etc/nova/ /var/lib/cinder/ \
	/var/lib/nova/ /var/lib/neutron/ /etc/placement/ /var/lib/openvswitch/ /etc/sysconfig/openstack-nova-novncproxy \
	/etc/swift/ /var/log/swift/

sudo rm -rf /home/stack/log/* /etc/ceilometer /etc/barbican /etc/gnocchi /var/log/gnocchi  \
	   /var/log/neutron /var/log/nova /var/log/placement /var/log/cinder /var/log/ceilometer

sudo rm -rf /var/lib/swift /var/lib/gnocchi /var/lib/ceilometer /var/lib/barbican /tmp/*  /etc/openvswitch/
sudo rm -rf /var/log/*.lsl  /etc/rsyncd.conf /var/cache/swift /etc/swift /etc/apache2 /etc/mysql /var/log/apache2 /var/log/mysql
sudo sed -i "s/^net.*$//g" /etc/sysctl.conf
sudo apt autoremove -y

