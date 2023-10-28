# openstack-zed
Login as user "stack" and generate ssh key pair
```
ssh-keygen -P ""
ssh-copy-id controller
ssh-copy-id compute
ssh-copy-id storage
```
```
/etc/hosts
10.10.0.11	controller
10.10.0.31	compute
10.10.0.41	storage
```
```
git clone https://github.com/Sangwan70/openstack-zed.git
```
```
cd scripts
stack@controller:~/scripts$ ./pre-download.sh
```
```
cd ubuntu
stack@controller:~/scripts/ubuntu$ ./apt_upgrade.sh
stack@controller:~/scripts/ubuntu$ ./install_rabbitmq.sh
stack@controller:~/scripts/ubuntu$
stack@controller:~/scripts/ubuntu$
stack@controller:~/scripts/ubuntu$
stack@controller:~/scripts/ubuntu$
stack@controller:~/scripts/ubuntu$
stack@controller:~/scripts/ubuntu$
stack@controller:~/scripts/ubuntu$
stack@controller:~/scripts/ubuntu$
```
