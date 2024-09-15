#!/bin/bash
(uname -a | grep "(x86_64|amd64)" &>/dev/null) && echo amd64 || echo arm64
