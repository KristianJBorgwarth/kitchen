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

# quickshell — not packaged for ubuntu, so build a pinned release (same version as arch).
# needs Qt >= 6.9 (the config uses QtQuick.Effects' RectangularShadow): ubuntu 25.10+
QS_VERSION="v0.3.1"
SOURCE_DIR="$HOME/source"
mkdir -p "$SOURCE_DIR"

sudo apt-get install -y \
    cmake ninja-build pkg-config spirv-tools libcli11-dev \
    qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev \
    qt6-shadertools-dev qt6-wayland-dev qt6-wayland-private-dev qt6-svg-dev \
    libwayland-dev wayland-protocols libdrm-dev libgbm-dev libvulkan-dev \
    libpipewire-0.3-dev libpam0g-dev libpolkit-agent-1-dev libglib2.0-dev \
    libxcb1-dev libjemalloc-dev
# runtime: wayland platform plugin, svg icons, and the QML modules the config imports
sudo apt-get install -y \
    qt6-wayland libqt6svg6 \
    qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-effects \
    qml6-module-qtqml-workerscript

QS_INSTALLED=""
if command -v qs >/dev/null 2>&1; then
    QS_INSTALLED="v$(qs --version | awk '{print $2}')"
fi

if [ "$QS_INSTALLED" != "$QS_VERSION" ]; then
    if [ -d "$SOURCE_DIR/quickshell" ]; then
        git -C "$SOURCE_DIR/quickshell" fetch --depth 1 origin tag "$QS_VERSION"
    else
        git clone --depth 1 --branch "$QS_VERSION" https://github.com/quickshell-mirror/quickshell.git "$SOURCE_DIR/quickshell"
    fi
    git -C "$SOURCE_DIR/quickshell" checkout "$QS_VERSION"
    # crash handler needs cpptrace, which ubuntu doesn't package.
    # installs to ~/.local: sudo here only allows apt/systemctl, not cmake
    cmake -S "$SOURCE_DIR/quickshell" -B "$SOURCE_DIR/quickshell/build" -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
        -DCRASH_HANDLER=OFF \
        -DDISTRIBUTOR="kitchen ubuntu-install.sh"
    cmake --build "$SOURCE_DIR/quickshell/build"
    cmake --install "$SOURCE_DIR/quickshell/build"
fi
sudo systemctl disable --now swayosd-libinput-backend.service


sudo apt install flatpak -y
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

