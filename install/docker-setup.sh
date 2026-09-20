#!/bin/bash
set -e

if ! command -v docker >/dev/null 2>&1; then
    echo "==> docker not installed, skipping docker setup"
    exit 0
fi

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

echo "==> Added $USER to the docker group, log out and back in (or run 'newgrp docker') to use docker without sudo"
