#!/bin/bash

# shell
echo "==> Installing zsh"
sudo pacman -Sy zsh
echo "==> Installing git"
sudo pacman -Sy git

# tiling applications
echo "==> Installing sway"
sudo pacman -Sy sway
echo "==> Installing waybar"
sudo pacman -Sy waybar
echo "==> Installing rofi"
sudo pacman -Sy rofi
echo "==> Installing mako-notifier"
sudo pacman -Sy mako-notifier
echo "==> Installing swaylock"
sudo pacman -Sy swaylock

## audio/video
echo "==> Installing pipewire"
sudo pacman -Sy pipewire
echo "==> Installing pipewire-pulse"
sudo pacman -Sy pipewire-pulse
echo "==> Installing pipewire-alsa"
sudo pacman -Sy pipewire-alsa
echo "==> Installing wireplumber"
sudo pacman -Sy wireplumber

# pkg manager
echo "==> Installing python-pipx"
sudo pacman -Sy python-pipx

# tools
echo "==> Installing cmake"
sudo pacman -Sy cmake
echo "==> Installing ninja-build"
sudo pacman -Sy ninja-build
echo "==> Installing unzip"
sudo pacman -Sy unzip
echo "==> Installing brightnessctl"
sudo pacman -Sy brightnessctl
echo "==> Installing swayosd"
sudo pacman -Sy swayosd

# dotnet
echo "==> Installing dotnet-sdk-10.0"
sudo pacman -Sy dotnet-sdk-10.0
