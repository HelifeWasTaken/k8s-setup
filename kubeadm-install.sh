#!/bin/bash

set -xe

cd "$(dirname $0)"

./check-prerequisities.sh ""

if [ $? -ne 0 ]; then
	exit 1
fi

#Install kubelet & kubeadm

CNI_PLUGINS_VERSION="v1.3.0"
ARCH="$(./get_arch.sh)"
CRICTL_VERSION="v1.31.0"
K8S_RELEASE_VERSION="v0.16.2"

LATEST_RELEASE="$(./get_stable_release.sh)"

CNI_DEST="/opt/cni/bin"
DOWNLOAD_DIR="/usr/local/bin"

CNI_PLUGIN_URL="https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz"
CRICTL_URL="https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" 

KBADM_KBLET_URL="https://dl.k8s.io/release/${LATEST_RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}"
K8S_RELEASE_BASE_URL="https://raw.githubusercontent.com/kubernetes/release/${K8S_RELEASE_VERSION}/cmd/krel/templates/latest"
KUBELET_TEMPLATE_SERVICE_URL="${K8S_RELEASE_BASE_URL}/kubelet/kubelet.service"
KUBEADM_TEMPLATE_CONF_URL="${K8S_RELEASE_BASE_URL}/kubeadm/10-kubeadm.conf"

KUBELET_SERVICE_PATH="/usr/lib/systemd/system/kubelet.service"
KUBEADM_CONF_PATH="/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf"

# Check aviability of the 6443 port
(nc 127.0.0.1 6443 -v 2>&1 | grep "Connection refused" &>/dev/null) || \
	(echo "127.0.0.1:6443 does not seem available but is required" 1>&2 && exit 1)

sudo mkdir -p "$CNI_DEST" "$DOWNLOAD_DIR" "$KUBELET_SERVICE_PATH.d"

curl -L "$CNI_PLUGIN_URL" | sudo tar -C "$CNI_DEST" -xz
curl -L "$CRICTL_URL"     | sudo tar -C "$DOWNLOAD_DIR" -xz

cd "$DOWNLOAD_DIR"

sudo curl -L --remote-name-all "$KBADM_KBLET_URL"
sudo chmod +x kubeadm kubelet

curl -sSL "${KUBELET_TEMPLATE_SERVICE_URL}" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee "$KUBELET_SERVICE_PATH"
curl -sSL "${KUBEADM_TEMPLATE_CONF_URL}"    | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee "$KUBEADM_CONF_PATH"

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

sudo systemctl enable --now kubelet
sudo systemctl enable --now containerd

echo "You may require to reboot your computer before kubeadm (use now init-kubeadm.sh)"

#kubeadm join 192.168.1.26:6443 --token 9v8mgl.d4ei0qvu6qwddlhf \
#	        --discovery-token-ca-cert-hash sha256:aa4e6555d80be599ccc7c567c2cbbca111115cd98a80ff8cd27cd61df7b28f20

