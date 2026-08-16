#!/bin/bash
set -e

SOURCE_DIR="$HOME/source"
mkdir -p "$SOURCE_DIR"

# pipx
python3 -m pipx ensurepath

# autotiling
if [ -d "$SOURCE_DIR/autotiling" ]; then
    git -C "$SOURCE_DIR/autotiling" pull
else
    git clone https://github.com/nwg-piotr/autotiling.git "$SOURCE_DIR/autotiling"
fi
pipx install --force "$SOURCE_DIR/autotiling"

# fzf
if [ -d "$HOME/.fzf" ]; then
    git -C "$HOME/.fzf" pull
else
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
fi
~/.fzf/install --all --no-update-rc


# zsh-autosuggestions
if [ -d "$SOURCE_DIR/zsh-autosuggestions" ]; then
    git -C "$SOURCE_DIR/zsh-autosuggestions" pull
else
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "$SOURCE_DIR/zsh-autosuggestions"
fi


# neovim (apt lags upstream — build a pinned stable release into ~/.local
# requires cmake + ninja-build,
# see packages.txt #build tools -> ubuntu-install.sh / arch-install.sh)
NVIM_VERSION="v0.12.4"
NVIM_BIN="$HOME/.local/bin/nvim"
NVIM_INSTALLED=""
if [ -x "$NVIM_BIN" ]; then
    NVIM_INSTALLED="$("$NVIM_BIN" --version | head -n1 | awk '{print $2}')"
fi

if [ "$NVIM_INSTALLED" != "$NVIM_VERSION" ]; then
    if [ -d "$SOURCE_DIR/neovim" ]; then
        git -C "$SOURCE_DIR/neovim" fetch --depth 1 origin tag "$NVIM_VERSION"
    else
        git clone --depth 1 --branch "$NVIM_VERSION" https://github.com/neovim/neovim.git "$SOURCE_DIR/neovim"
    fi
    git -C "$SOURCE_DIR/neovim" checkout "$NVIM_VERSION"
    make -C "$SOURCE_DIR/neovim" CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$HOME/.local"
    make -C "$SOURCE_DIR/neovim" install
fi

# clone nvim config 
if [ -d "$HOME/nvim" ]; then
    git -C "$HOME/nvim" pull
else
    git clone --depth 1 https://github.com/KristianJBorgwarth/nvim.git "$HOME/nvim"
fi

# zoxide
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# go (official tarball install, per https://go.dev/doc/install) 
GO_ARCH="$(uname -m)"
case "$GO_ARCH" in
    x86_64) GO_ARCH="amd64" ;;
    aarch64) GO_ARCH="arm64" ;;
esac

GO_LATEST="$(curl -sSfL https://go.dev/VERSION?m=text | head -n1)"
GO_INSTALLED=""
if command -v go >/dev/null 2>&1; then
    GO_INSTALLED="$(go version | awk '{print $3}')"
fi

if [ "$GO_INSTALLED" != "$GO_LATEST" ]; then
    mkdir -p "$HOME/opt"
    curl -sSfL "https://go.dev/dl/${GO_LATEST}.linux-${GO_ARCH}.tar.gz" -o "/tmp/${GO_LATEST}.tar.gz"
    rm -rf "$HOME/opt/go"
    tar -C "$HOME/opt" -xzf "/tmp/${GO_LATEST}.tar.gz"
    rm "/tmp/${GO_LATEST}.tar.gz"
fi

export PATH="$HOME/opt/go/bin:$HOME/go/bin:$PATH"

# k9s (can be installed with home_brew, but i don't want 6000 package managers)
K9S_VERSION="v0.51.0"
K9S_BIN="$HOME/.local/bin/k9s"
K9S_INSTALLED=""
if [ -x "$K9S_BIN" ]; then
    K9S_INSTALLED="$("$K9S_BIN" version --short | head -n1 | awk '{print $2}')"
fi
if [ "$K9S_INSTALLED" != "$K9S_VERSION" ]; then
    if [ -d "$SOURCE_DIR/k9s" ]; then
        git -C "$SOURCE_DIR/k9s" fetch --depth 1 origin tag "$K9S_VERSION"
    else
        git clone --depth 1 --branch "$K9S_VERSION" https://github.com/derailed/k9s.git "$SOURCE_DIR/k9s"
    fi
    git -C "$SOURCE_DIR/k9s" checkout "$K9S_VERSION"
    make -C "$SOURCE_DIR/k9s" build
    cp "$SOURCE_DIR/k9s/execs/k9s" "$K9S_BIN"
fi

# kubectl (official static binary — k8s.io/kubectl)
KUBECTL_LATEST="$(curl -sSfL https://dl.k8s.io/release/stable.txt)"
curl -sSfL "https://dl.k8s.io/release/${KUBECTL_LATEST}/bin/linux/${GO_ARCH}/kubectl" -o "$HOME/.local/bin/kubectl"
chmod +x "$HOME/.local/bin/kubectl"


# dendrite (markdown note engine)
curl -fsSL https://raw.githubusercontent.com/KristianJBorgwarth/dendrite.daemon/master/install.sh | sh

# JetBrains Mono Nerd Font (waybar/ghostty rely on its PUA glyphs)
NERD_FONT_VERSION="v3.5.0"
NERD_FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
if [ ! -f "$NERD_FONT_DIR/.version" ] || [ "$(cat "$NERD_FONT_DIR/.version")" != "$NERD_FONT_VERSION" ]; then
    mkdir -p "$NERD_FONT_DIR"
    curl -sSfL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip" -o "/tmp/JetBrainsMonoNerdFont.zip"
    unzip -o -q "/tmp/JetBrainsMonoNerdFont.zip" -d "$NERD_FONT_DIR" -x "*Windows Compatible*"
    rm "/tmp/JetBrainsMonoNerdFont.zip"
    echo "$NERD_FONT_VERSION" > "$NERD_FONT_DIR/.version"
    fc-cache -f "$NERD_FONT_DIR"
fi

# oh-my-posh
curl -s https://ohmyposh.dev/install.sh | bash -s

# fnm (fast node manager, drop-in replacement for nvm)
curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fnm install --latest
