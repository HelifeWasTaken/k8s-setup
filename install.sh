#!/bin/bash

set -e

UBUNTU_VERSION_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
ARCH="$(dpkg --print-architecture)"
SWAP_DISK="$(sudo systemctl --type swap --plain --legend=no | cut -d ' ' -f 1)"

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

FIREWALL_PORTS_TO_ALLOW_PERMANENTLY=(
	6443/tcp
 	10250/tcp
)

SYSTEM_SERVICES_TO_START=(
	containerd
 	kubelet
  	docker
)

KUBERNETES_APT_PACKAGE_STRING='deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /'
DOCKER_APT_PACKAGE_STRING="deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $UBUNTU_VERSION_CODENAME stable"

K8S_RELEASE_KEY_URL='https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key'
DOCKER_GPG_URL='https://download.docker.com/linux/ubuntu/gpg'

# Prepare packages
sudo install -m 0755 -d /etc/apt/keyrings
sudo apt-get update -y && sudo apt-get install -y "${PRE_REQUIRE_PACKAGES[@]}"

# Set keyrings for docker
sudo curl -fsSL "$DOCKER_GPG_URL" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "$DOCKER_APT_PACKAGE_STRING" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Set keyrings for k8s
curl -fsSL "$K8S_RELEASE_KEY_URL"     | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "$KUBERNETES_APT_PACKAGE_STRING" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# remove conflicting packages and update the package list
sudo apt-get remove "${CONFLICTING_PACKAGES[@]}" -y && sudo apt update -y && sudo apt-get update -y

# Installed default required packages
sudo apt-get install -y "${CONTAINER_PACKAGES[@]}"

# Deactivate swap for the machine for k8s functionality
sudo swapoff -a
for swap in "${SWAP_DISKS[@]}"; do sudo systemctl mask "$swap" ; done

# Set ports for kubelet kubeadm and kubectl
for port in "${FIREWALL_PORTS_TO_ALLOW_PERMANENTLY[@]}"; do sudo firewall-cmd --add-port=$port --permanent ; done
sudo firewall-cmd --reload

# Enable ip forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Install kube(*)
sudo apt-get install -y "${K8S_PACKAGES[@]}" && sudo apt-mark hold "${K8S_PACKAGES[@]}"

# Enable the services
for service in "${SYSTEM_SERVICES_TO_START[@]}"; do sudo systemctl enable --now "$service" ; done

# Init kubeadm and copies it's configuration
sudo kubeadm init

if [ ! -z "$HOME" ]; then
	mkdir -p "$HOME/.kube"
	sudo cp -i "/etc/kubernetes/admin.conf" "$HOME/.kube/config"
	sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
fi
