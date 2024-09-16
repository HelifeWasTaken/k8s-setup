#!/bin/bash

set -xe
cd "$(dirname $0)"

./check-prerequisities.sh ""

if [ $? -ne 0 ]; then
	exit 1
fi

HOSTNAME="https://dl.k8s.io"
ARCH=$(./get_arch.sh)
RELEASE=$(./get_stable_release.sh)

curl -LO "$HOSTNAME/release/$RELEASE/bin/linux/$ARCH/kubectl"
curl -LO "$HOSTNAME/release/$RELEASE/bin/linux/$ARCH/kubectl.sha256"

echo "$(cat kubectl.sha256) kubectl" | sha256sum --check

sudo install -o root -g root -m 0775 kubectl /usr/local/bin/kubectl

kubectl version --client --output=yaml
