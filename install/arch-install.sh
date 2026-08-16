#!/bin/bash
PKGFILE="packages.txt"
SOURCE_DIR="$HOME/source"
mkdir -p "$SOURCE_DIR"

sudo pacman -Sy

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue 
  case "$pkg" in \#*) continue ;; esac
  echo "==> Installing $pkg"
  sudo pacman -S --needed --noconfirm "$pkg"
done < "$PKGFILE"

sudo pacman -S --needed base-devel
sudo pacman -S openssh
sudo pacman -S network-manager-applet
sudo pacman -S --needed papirus-icon-theme nwg-look qt5ct qt6ct

if [ -d "$SOURCE_DIR/yay" ]; then
    git -C "$SOURCE_DIR/yay" pull
else
    git clone https://aur.archlinux.org/yay.git "$SOURCE_DIR/yay"
fi

(cd "$SOURCE_DIR/yay" && makepkg -si --noconfirm)

yay -Sy waypaper
