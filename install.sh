#!/bin/bash

if [ "$EUID" != 0 ]; then
        echo "Please run as root" 1>&2
        exit 1
fi

if [ -z "$NETWORK_INTERFACE" ]; then
	NETWORK_INTERFACE=eth0
fi

set -e

NETWORK_INTERFACE_IP="$(ifconfig $NETWORK_INTERFACE | perl -nle '/(\d+\.\d+\.\d+\.\d+)/ && print $1')"

if [ -z "$NETWORK_INTERFACE_IP" ]; then
	echo "Cloud not get the network interface IP for $NETWORK_INTERFACE"
	exit 1
fi

CONFLICTING_PACKAGES=docker.io \
		docker-doc \
		docker-compose \
		docker-compose-v2 \
		podman-docker \
		containerd \
		runc

PRE_REQUIRE_PACKAGES=apt-transport-https \
			ca-certificates \
			curl \
			gpg \
			wget \
			socat \
			conntrack \
			firewalld \
			croup-tools \
			'libcgroup*'

KUBERNETES_APT_PACKAGE_STRING='deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /'
DOCKER_APT_PACKAGE_STRING="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable"

K8S_RELEASE_KEY_URL='https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key'
DOCKER_GPG_URL='https://download.docker.com/linux/ubuntu/gpg'

CONTAINER_PACKAGES=docker-ce \
		docker-ce-cli \
		containerd.io \
		docker-buildx-plugin \
		docker-compose-plugin

# Prepare packages
install -m 0755 -d /etc/apt/keyrings
apt-get update -y
apt-get install -y $PRE_REQUIRE_PACKAGES

# Set keyrings for docker
curl -fsSL "$DOCKER_GPG_URL" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "$DOCKER_APT_PACKAGE_STRING" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Set keyrings for k8s
curl -fsSL "$K8S_RELEASE_KEY_URL"     | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "$KUBERNETES_APT_PACKAGE_STRING" | tee /etc/apt/sources.list.d/kubernetes.list

# Update the package list
apt update -y && apt-get update -y

# remove possible conflicting packages
for pkg in $CONFLICTING_PACKAGES; do
	apt-get remove $pkg || echo -ne "" # do not fail in case -x is set
done

# Installed default required packages
apt-get install -y $CONTAINER_PACKAGES

# Deactivate swap for the machine for k8s functionality
swapoff -a
swaps="$(systemctl --type swap --plain --legend=no | xargs -n1 grep ".swap")"
for swap in $swaps; do
        systemctl mask "$swap"
done

# Set ports for kubelet kubeadm and kubectl
firewall-cmd --add-port=6443/tcp --permanent
firewall-cmd --add-port=10250/tcp --permanent
firewall-cmd --reload

# Enable ip forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | tee -a /etc/sysctl.conf
sysctl -p

# Install kube(*)
apt-get install -y kubelet kubeadm kubectl 
apt-mark hold kubelet kubeadm kubectl

# Enable the services
systemctl enable --now containerd
systemctl enable --now kubelet
systemctl enable --now docker

# Init kubeadm and copies it's configuration
cat /etc/containerd/config.toml | sed 's/disabled_plugins = \["cri"\]/disabled_plugins = []/g' > /etc/containerd/config.toml
#If kubeadm complains of missing hugetlb cgroups
#To /etc/default/grub change GRUB_CMD_LINUX_DEFAULT
#GRUB_CMDLINE_LINUX_DEFAULT="cgroup_enable=hugetlb"
#If it is an issue with cri check the disabled_plugins maybe it is not disabled properly
kubeadm init || (echo "Check troubleshooting with the kubeadm init comments inside the script"; exit 1)

# Update the home configuration
if [ ! -z "$HOME" ]; then
	mkdir -p "$HOME/.kube"
	cp "/etc/kubernetes/admin.conf" "$HOME/.kube/config"
	chown "$(id -u):$(id -g)" "$HOME/.kube/config"
fi

# Install helm for 'packages'
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install flanneld for networking
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

helm repo add flannel https://flannel-io.github.io/flannel/
helm install flannel --set podCidr="10.244.0.0/16" --namespace kube-flannel flannel/flannel
