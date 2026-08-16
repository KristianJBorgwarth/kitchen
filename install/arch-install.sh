#!/bin/bash
PKGFILE="packages.txt"
SOURCE_DIR="$HOME/source"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$SOURCE_DIR"

sudo pacman -Sy

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue 
  case "$pkg" in \#*) continue ;; esac
  echo "==> Installing $pkg"
  sudo pacman -S --needed --noconfirm "$pkg"
done < "$PKGFILE"

sudo pacman -S --needed --noconfirm base-devel
sudo pacman -S --needed --noconfirm openssh
sudo pacman -S --needed --noconfirm network-manager-applet
sudo pacman -S --needed --noconfirm papirus-icon-theme nwg-look qt5ct qt6ct
sudo pacman -S --needed --noconfirm greetd


if [ -d "$SOURCE_DIR/yay" ]; then
    git -C "$SOURCE_DIR/yay" pull
else
    git clone https://aur.archlinux.org/yay.git "$SOURCE_DIR/yay"
fi
(cd "$SOURCE_DIR/yay" && makepkg -si --noconfirm)


yay -Sy
yay -S --needed --noconfirm waypaper greetd-tuigreet

# login manager
sudo systemctl enable greetd
sudo mkdir -p /etc/greetd
sudo ln -sf ${REPO_DIR}/greetd/config.toml /etc/greetd/config.toml
