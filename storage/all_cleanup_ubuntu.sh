sudo apt remove -y --purge python3-wcwidth
sudo apt remove -y --purge python3-cmd2
sudo apt remove -y --purge python3-oslo.utils python3-docutils python3-oslo.serialization python3-oslo.context python3-deprecation python3-cliff python3-docutils
sudo apt remove -y --purge barbican-api
sudo apt remove -y --purge git
sudo apt remove -y --purge python3-pip virtualenv python3-openstackclient cinder-api cinder-scheduler
sudo apt remove -y --purge python3-openstackclient
sudo apt remove -y --purge cinder-api cinder-scheduler
sudo apt remove -y --purge cinder-scheduler
sudo apt remove -y --purge swift
sudo apt remove -y --purge swift-account
sudo apt remove -y --purge python3-swift python3-swiftclient  nova-api nova-conductor nova-novncproxy nova-scheduler
sudo rm -rf /etc/cinder/ /etc/neutron/ /var/lib/cinder/ /var/lib/neutron/ /var/lib/openvswitch/ /etc/sysconfig/openstack-nova-novncproxy \
        /etc/swift/ /var/log/swift/

sudo rm -rf /home/stack/log/* /etc/ceilometer /etc/barbican /etc/gnocchi  /var/log/gnocchi \
           /var/log/neutron /var/log/cinder /var/log/ceilometer /tmp/*

sudo rm -rf /var/lib/swift /var/lib/gnocchi /var/lib/ceilometer /var/lib/barbican /tmp/* /etc/openvswitch/
sudo rm -rf /var/cache/swift /etc/swift
sudo rm -rf /var/cache/barbican  /var/cache/cinder /var/cache/neutron  /var/cache/nova
sudo rm -rf /var/log/*.lsl /etc/rsyncd.conf  /etc/rsyslog.conf
sudo sed -i "s/^net.*$//g" /etc/sysctl.conf
sudo apt autoremove -y

