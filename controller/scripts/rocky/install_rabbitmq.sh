#!/usr/bin/env bash

set -o errexit -o nounset

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)

source "$TOP_DIR/config/paths"
source "$CONFIG_DIR/credentials"
source "$LIB_DIR/functions.guest.sh"

exec_logfile

indicate_current_auto

#-------------------------------------------------------------------------------
# Install the message broker service (RabbitMQ).
#-------------------------------------------------------------------------------

echo "Installing RabbitMQ."
sudo dnf install -y rabbitmq-server policycoreutils checkpolicy


sudo systemctl enable rabbitmq-server.service
sudo systemctl restart rabbitmq-server.service
sudo firewall-cmd --permanent --add-port={11211,5672}/tcp 
sudo firewall-cmd --reload

sudo touch rabbitmqctl.te

cat <<EOF | sudo tee -a rabbitmqctl.te
module rabbitmqctl 1.0;

require {
        type rabbitmq_t;
        type rabbitmq_var_log_t;
        type rabbitmq_var_lib_t;
        type etc_t;
        type init_t;
        class file write;
        class file getattr;
}

#============= rabbitmq_t ==============
allow rabbitmq_t etc_t:file write;

#============= init_t ==================
allow init_t rabbitmq_var_lib_t:file getattr;
allow init_t rabbitmq_var_log_t:file getattr;
EOF

sudo checkmodule -m -M -o rabbitmqctl.mod rabbitmqctl.te
sudo semodule_package --outfile rabbitmqctl.pp --module rabbitmqctl.mod
sudo semodule -i rabbitmqctl.pp


echo -n "Waiting for RabbitMQ to start."
until sudo rabbitmqctl status >/dev/null; do
    sleep 1
    echo -n .
done
echo

echo ---------------------------------------------------------------
echo "sudo rabbitmqctl status"
sudo rabbitmqctl status
echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "sudo rabbitmqctl report"
sudo rabbitmqctl report
echo ---------------------------------------------------------------

echo "Adding openstack user to messaging service."
sudo rabbitmqctl add_user openstack "$RABBIT_PASS"

echo "Permitting configuration, write and read access for the openstack user."
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"
