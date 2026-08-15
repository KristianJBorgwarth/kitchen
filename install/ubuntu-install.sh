
# tiling applications
echo "==> Installing waybar"
sudo apt install -y waybar
echo "==> Installing rofi"
sudo apt install -y rofi
echo "==> Installing network-manager-gnome"
sudo apt-get install -y network-manager-gnome
echo "==> Installing xdg-desktop-portal-wlr"
sudo apt install -y xdg-desktop-portal-wlr
echo "==> Installing mako-notifier"
sudo apt install -y mako-notifier

# pkg manager
echo "==> Installing pipx"
sudo apt install -y pipx

# tools
echo "==> Installing cmake"
sudo apt install -y cmake
echo "==> Installing ninja-build"
sudo apt install -y ninja-build
echo "==> Installing unzip"
sudo apt install -y unzip
echo "==> Installing brightnessctl"
sudo apt install -y brightnessctl
echo "==> Installing swayosd"
sudo apt install -y swayosd
echo "==> Disabling swayosd-libinput-backend.service"
sudo systemctl disable --now swayosd-libinput-backend.service

# dotnet
echo "==> Installing dotnet-sdk-10.0"
sudo apt install -y dotnet-sdk-10.0

