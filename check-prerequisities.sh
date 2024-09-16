#!/bin/bash

set -xe

commands="wget curl socat docker containerd conntrack firewall-cmd sysctll swapoff systemctl $1"
r=0

for cmd in $commands; do
	if ! command -v "$cmd" &>/dev/null; then
		echo "$cmd is required but not present on the OS" 1>&2
		r=1
	fi
done

echo $r
