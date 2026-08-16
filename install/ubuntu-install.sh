#!/bin/bash
PKGFILE="packages.txt"

sudo apt-get update

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  case "$pkg" in \#*) continue ;; esac
  echo "==> Installing $pkg"
  sudo apt-get install -y "$pkg"
done < "$PKGFILE"

sudo apt-get install -y network-manager-gnome
sudo systemctl disable --now swayosd-libinput-backend.service
