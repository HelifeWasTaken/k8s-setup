#!/bin/bash

set -xe

cd "$(dirname $0)"

./check-prerequisities.sh "kubectl kubeadm kubelet"

sudo systemctl enable --now containerd
sudo systemctl enable --now kubelet

sudo kubeadm init

if [ ! -z "$HOME" ]; then
        mkdir -p "$HOME/.kube"
        sudo cp -i "/etc/kubernetes/admin.conf" "$HOME/.kube/config"
        sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
fi
