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

# kubectl (official static binary — k8s.io/kubectl)
KUBECTL_LATEST="$(curl -sSfL https://dl.k8s.io/release/stable.txt)"
curl -sSfL "https://dl.k8s.io/release/${KUBECTL_LATEST}/bin/linux/${GO_ARCH}/kubectl" -o "$HOME/.local/bin/kubectl"
chmod +x "$HOME/.local/bin/kubectl"

# dendrite (markdown note engine)
curl -fsSL https://raw.githubusercontent.com/KristianJBorgwarth/dendrite.daemon/master/install.sh | sh

# oh-my-posh
curl -s https://ohmyposh.dev/install.sh | bash -s

# nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
