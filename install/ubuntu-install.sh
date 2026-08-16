#!/bin/bash
PKGFILE="packages.txt"

while IFS= read -r pkg; do 
  [ -z "$pkg" ] && continue # skip blank lines
  case "$pkg" in \#*) continue ;; esac  # skip comment lines starting with # 
  echo "==> Installing $pkg"
  sudo pacman -Sy "$pkg"
done < "$PKGFILE"

sudo apt-get install -y network-manager-gnome
sudo systemctl disable --now swayosd-libinput-backend.service
