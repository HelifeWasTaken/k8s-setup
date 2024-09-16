#!/bin/bash

set -xe

echo "$(curl -L -s "https://dl.k8s.io/release/stable.txt")"
