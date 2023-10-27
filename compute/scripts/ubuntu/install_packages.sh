sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall ifupdown curl tree network-manager git
sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall python3-openstackclient python3-pip python3-osc-placement
sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall nova-compute nova-api nova-conductor nova-novncproxy nova-scheduler placement-api
sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall neutron-common neutron-plugin-ml2 neutron-openvswitch-agent

sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall cinder-api cinder-scheduler
sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall swift swift-account swift-container swift-proxy swift-object xfsprogs python3-swift python3-swiftclient
sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall barbican-api barbican-worker barbican-keystone-listener

sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall nova-compute nova-compute-qemu
sudo apt install -y  -o DPkg::options::=--force-confmiss --reinstall lvm2 thin-provisioning-tools python3-swiftclient rsync
