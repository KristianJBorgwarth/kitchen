#!/bin/bash
PKGFILE="packages.txt"
SOURCE_DIR="$HOME/source"
mkdir -p "$SOURCE_DIR"

while IFS= read -r pkg; do 
  [ -z "$pkg" ] && continue # skip blank lines
  case "$pkg" in \#*) continue ;; esac  # skip comment lines starting with # 
  echo "==> Installing $pkg"
  sudo pacman -Sy "$pkg"
done < "$PKGFILE"

sudo pacman -S --needed base-devel
sudo pacman -S openssh
sudo pacman -S network-manager-applet

# gtk/qt theming
sudo pacman -S --needed papirus-icon-theme nwg-look qt5ct qt6ct

if [ -d "$SOURCE_DIR/yay" ]; then
    git -C "$SOURCE_DIR/yay" pull
else
    git clone https://aur.archlinux.org/yay.git "$SOURCE_DIR/yay"
fi

(cd "$SOURCE_DIR/yay" && makepkg -si --noconfirm)

yay -Sy waypaper
