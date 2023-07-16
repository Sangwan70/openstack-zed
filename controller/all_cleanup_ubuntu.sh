sudo apt remove -y python3-wcwidth python3-cmd2 xml-core ieee-data libpaper-utils
sudo apt remove -y python-babel-localedata python3-appdirs python3-babel python3-bs4 python3-os-service-types python3-netaddr python3-roman python3-crypto
sudo apt remove -y python3-decorator python3-mako python3-html5lib python3-monotonic
sudo apt remove -y python3-oslo.utils python3-docutils python3-oslo.serialization python3-oslo.context python3-deprecation python3-cliff python3-docutils
sudo apt remove -y python3-wrapt python3-keystoneauth1 libjbig0 libjpeg8 python3-dogpile.cache python3-oslo.log mariadb-server python3-mysqldb barbican-api barbican-worker barbican-keystone-listener
sudo apt remove -y memcached python3-memcache
sudo apt remove -y git python-pip virtualenv libmysqlclient-dev python-networking-sfc heat-api heat-api-cfn heat-engine python3-openstackclient cinder-api cinder-scheduler
sudo apt remove -y placement-api python3-pip openstack-dashboard glance rabbitmq-server swift swift-account swift-container swift-object swift-proxy xfsprogs
sudo apt remove -y python3-swift python3-swiftclient  keystone nova-api nova-conductor nova-novncproxy nova-scheduler

sudo rm -rf /etc/cinder/ /etc/glance/ /etc/apache2/ /etc/keystone/ /etc/my.cnf.d/ /etc/neutron/ /etc/nova/ /var/lib/cinder/ \
	/var/lib/apache2/ /var/lib/keystone/ /var/lib/mysql/ /var/lib/glance/ /var/lib/nova/ /var/lib/openstack-dashboard/ \
	/var/lib/neutron/ /etc/placement/ /etc/rabbitmq/ /var/lib/openvswitch/ /var/lib/rabbitmq/ /etc/sysconfig/openstack-nova-novncproxy \
	/etc/swift/ /var/log/swift/ /etc/sysconfig/memcached 

sudo rm -rf /home/stack/log/* /etc/ceilometer /etc/barbican /etc/gnocchi /etc/heat /var/log/glance /var/log/gnocchi /var/log/heat \
	   /var/log/neutron /var/log/nova /var/log/placement /var/log/rabbitmq  /var/log/cinder /var/log/ceilometer /var/log/apache2 \
	   /var/log/mariadb /tmp/*

sudo rm -rf /var/lib/swift /var/lib/gnocchi /var/lib/heat /var/lib/ceilometer /var/lib/barbican /tmp/*  /etc/openstack-dashboard/ /etc/openvswitch/
sudo rm -rf /var/log/*.lsl
sudo sed -i "s/^net.*$//g" /etc/sysctl.conf
sudo apt autoremove

