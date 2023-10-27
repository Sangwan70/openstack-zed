sudo apt remove -y --purge python3-wcwidth 
sudo apt-get -y remove apache2
sudo apt-get -y purge apache2
sudo apt autoremove
sudo apt remove -y --purge python3-cmd2
sudo apt remove -y --purge python3-oslo.utils python3-docutils python3-oslo.serialization python3-oslo.context python3-deprecation python3-cliff python3-docutils
sudo apt remove -y --purge mariadb-server 
sudo apt purge mysql-common
sudo apt purge mariadb-server
sudo apt autoremove
sudo apt remove -y --purge barbican-api 
sudo apt remove -y --purge memcached
sudo apt remove -y --purge git 
sudo apt remove -y --purge python3-pip virtualenv heat-api heat-api-cfn heat-engine python3-openstackclient cinder-api cinder-scheduler
sudo apt remove -y --purge heat-api
sudo apt remove -y --purge heat-engine
sudo apt remove -y --purge python3-openstackclient
sudo apt remove -y --purge cinder-api cinder-scheduler
sudo apt remove -y --purge cinder-scheduler
sudo apt remove -y --purge placement-api 
sudo apt remove -y --purge openstack-dashboard
sudo apt remove -y --purge glance 
sudo apt remove -y --purge rabbitmq-server 
sudo apt remove -y --purge swift 
sudo apt remove -y --purge swift-account
sudo apt remove -y --purge python3-swift python3-swiftclient keystone nova-api nova-conductor nova-novncproxy nova-scheduler

sudo rm -rf /etc/cinder/ /etc/glance/ /etc/apache2/ /etc/mysql /etc/keystone/ /etc/my.cnf.d/ /etc/neutron/ /etc/nova/ /var/lib/cinder/ \
	/var/lib/apache2/ /var/lib/keystone/ /var/lib/placement /var/lib/mysql /var/lib/glance/ /var/lib/nova/ /var/lib/openstack-dashboard/ \
	/var/lib/neutron/ /etc/placement/ /etc/rabbitmq/ /var/lib/openvswitch/ /var/lib/rabbitmq/ /etc/sysconfig/openstack-nova-novncproxy \
	/etc/swift/ /var/log/swift/ /etc/sysconfig/memcached 

sudo rm -rf /home/stack/log/* /etc/ceilometer /etc/barbican /etc/gnocchi /etc/heat /var/log/glance /var/log/gnocchi /var/log/heat \
	   /var/log/neutron /var/log/nova /var/log/placement /var/log/rabbitmq  /var/log/cinder /var/log/ceilometer /var/log/apache2 \
	   /var/log/mariadb /tmp/*

sudo rm -rf /var/lib/swift /var/lib/gnocchi /var/lib/heat /var/lib/ceilometer /var/lib/barbican /tmp/*  /etc/openstack-dashboard/ /etc/openvswitch/
sudo rm -rf /var/cache/swift /etc/swift
sudo rm -rf /var/cache/apache2 /var/cache/barbican /var/cache/cinder /var/cache/glance /var/cache/heat  /var/cache/neutron  /var/cache/nova
sudo rm -rf /var/log/*.lsl
sudo sed -i "s/^net.*$//g" /etc/sysctl.conf
sudo apt autoremove -y

