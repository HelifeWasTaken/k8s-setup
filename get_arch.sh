#!/bin/bash
set -xe
(uname -a | grep -E "x86_64|amd64" &>/dev/null) && echo amd64 || echo arm64
