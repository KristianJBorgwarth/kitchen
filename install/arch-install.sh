#!/bin/bash

# tiling applications
echo "==> Installing sway"
sudo pacman -S sway
echo "==> Installing waybar"
sudo pacman -S waybar
echo "==> Installing rofi"
sudo pacman -S rofi
echo "==> Installing mako-notifier"
sudo pacman -S mako-notifier

## audio/video
echo "==> Installing pipewire"
sudo pacman -S pipewire
echo "==> Installing pipewire-pulse"
sudo pacman -S pipewire-pulse
echo "==> Installing pipewire-alsa"
sudo pacman -S pipewire-alsa
echo "==> Installing wireplumber"
sudo pacman -S wireplumber

# pkg manager
echo "==> Installing python-pipx"
sudo pacman -S python-pipx

# tools
echo "==> Installing cmake"
sudo pacman -S cmake
echo "==> Installing ninja-build"
sudo pacman -S ninja-build
echo "==> Installing unzip"
sudo pacman -S unzip
echo "==> Installing brightnessctl"
sudo pacman -S brightnessctl
echo "==> Installing swayosd"
sudo pacman -S swayosd

# dotnet
echo "==> Installing dotnet-sdk-10.0"
sudo pacman -S dotnet-sdk-10.0
