# Deploy k8s

If you prefer to rely on Ubuntu and it's package manager: [Here](https://github.com/HelifeWasTaken/k8s-setup/tree/ubuntu)

How to install properly k8s:
```sh
./kubectl-install.sh
./kubeadm-setup-conf.sh
# reboot
./kubeadm-install.sh
./init-kubeadm.sh
```
