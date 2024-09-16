#!/bin/bash

set -e

CONFLICTING_PACKAGES=(
	docker.io
	docker-doc
	docker-compose
	docker-compose-v2
	podman-docker
	containerd
	runc
)

PRE_REQUIRE_PACKAGES=(
	apt-transport-https
	ca-certificates
	curl
	gpg
	wget
	socat
	conntrack
	firewalld
)

CONTAINER_PACKAGES=(
	docker-ce
	docker-ce-cli
	containerd.io
	docker-buildx-plugin
	docker-compose-plugin
)

K8S_PACKAGES=(
	kubelet
	kubeadm
	kubectl
)

KUBERNETES_APT_PACKAGE_STRING='deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /'
DOCKER_APT_PACKAGE_STRING="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable"

K8S_RELEASE_KEY_URL='https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key'
DOCKER_GPG_URL='https://download.docker.com/linux/ubuntu/gpg'

# Prepare packages
sudo install -m 0755 -d /etc/apt/keyrings
sudo apt-get update -y
sudo apt-get install -y $PRE_REQUIRE_PACKAGES[@]

# Set keyrings for docker
sudo curl -fsSL "$DOCKER_GPG_URL" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "$DOCKER_APT_PACKAGE_STRING" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Set keyrings for k8s
curl -fsSL "$K8S_RELEASE_KEY_URL"     | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "$KUBERNETES_APT_PACKAGE_STRING" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update the package list
sudo apt update -y && sudo apt-get update -y

# remove possible conflicting packages
for pkg in $CONFLICTING_PACKAGES; do
	sudo apt-get remove $pkg || echo -ne "" # do not fail in case -x is set
done

# Installed default required packages
sudo apt-get install -y $CONTAINER_PACKAGES[@]

# Deactivate swap for the machine for k8s functionality
sudo swapoff -a
swaps="$(sudo systemctl --type swap --plain --legend=no | xargs -n1 grep ".swap")"
for swap in $swaps; do
        sudo systemctl mask "$swap"
done

# Set ports for kubelet kubeadm and kubectl
sudo firewall-cmd --add-port=6443/tcp --permanent
sudo firewall-cmd --add-port=10250/tcp --permanent
sudo firewall-cmd --reload

# Enable ip forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Install kube(*)
sudo apt-get install -y $K8S_PACKAGES[@]
sudo apt-mark hold $K8S_PACKAGES[@]

# Enable the services
sudo systemctl enable --now containerd
sudo systemctl enable --now kubelet
sudo systemctl enable --now docker

# Init kubeadm and copies it's configuration
sudo kubeadm init

if [ ! -z "$HOME" ]; then
	mkdir -p "$HOME/.kube"
	sudo cp -i "/etc/kubernetes/admin.conf" "$HOME/.kube/config"
	sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
fi
