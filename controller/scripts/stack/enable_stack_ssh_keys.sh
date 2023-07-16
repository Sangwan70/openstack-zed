#!/usr/bin/env bash
set -o errexit -o nounset

# This script installs the insecure stack ssh keys. This allows users to
# log into the VMs using these keys instead of a password.

TOP_DIR=$(cd $(cat "../TOP_DIR" 2>/dev/null||echo $(dirname "$0"))/.. && pwd)
source "$TOP_DIR/config/paths"
source "$LIB_DIR/functions.guest.sh"

indicate_current_auto

exec_logfile

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Install the requested stack insecure key to $HOME/.ssh.
function get_stack_key {
    local key_name=$1
    local stack_key_dir=$LIB_DIR/stack-ssh-keys

    if [ -f "$HOME/.ssh/$key_name" ]; then
        echo "stack insecure key already installed: $HOME/.ssh/$key_name."
    else
        echo "Installing stack insecure key $key_name."
        cp -v "$stack_key_dir/$key_name" "$HOME/.ssh"
    fi
}

# Authorize named key for ssh logins into this VM.
function authorize_stack_key {
    local pub_key_path=$1
    local auth_key_path=$HOME/.ssh/authorized_keys
    if grep -qs "stack insecure public key" "$auth_key_path"; then
        echo "Already authorized."
    else
        cat "$pub_key_path" >> "$auth_key_path"
    fi
}

echo "Installing stack insecure private key (connections to other VMs)."
get_stack_key "stack_key"
chmod 400 "$HOME/.ssh/stack_key"

get_stack_key "stack_key.pub"
chmod 444 "$HOME/.ssh/stack_key.pub"

echo "Authorizing stack public key (connections from host and other VMs)."
authorize_stack_key "$HOME/.ssh/stack_key.pub"
