#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$HOME/.config"
mkdir -p "$CONFIG_DIR"

link() {
    local src="$1" dest="$2"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "$dest.bak"
        echo "backed up existing $dest -> $dest.bak"
    fi
    ln -sfn "$src" "$dest"
    echo "linked $dest -> $src"
}

for app in fastfetch ghostty k9s kanshi mako rofi sway swaylock waybar; do
    link "$REPO_DIR/$app" "$CONFIG_DIR/$app"
done

link "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
link "$HOME/nvim" "$HOME/.config/nvim"
