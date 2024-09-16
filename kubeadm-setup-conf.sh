#!/bin/bash

set -xe

cd "$(dirname $0)"
./check-prerequisities.sh ""

if [ $? -ne 0 ]; then
	exit 1
fi

sudo firewall-cmd --add-port=6443/tcp --permanent
sudo firewall-cmd --add-port=10250/tcp --permanent
sudo firewall-cmd --reload

# Deactivate swap on the machine permanently
sudo swapoff -a
swaps="$(sudo systemctl --type swap --plain --legend=no | xargs -n1 grep ".swap")"
for swap in $swaps; do
        sudo systemctl mask "$swap"
done

sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
