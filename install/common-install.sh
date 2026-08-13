#!/bin/bash
set -e

SOURCE_DIR="$HOME/source"
mkdir -p "$SOURCE_DIR"

# pipx
if ! command -v pipx >/dev/null 2>&1; then
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath
fi

# autotiling
if [ -d "$SOURCE_DIR/autotiling" ]; then
    git -C "$SOURCE_DIR/autotiling" pull
else
    git clone https://github.com/nwg-piotr/autotiling.git "$SOURCE_DIR/autotiling"
fi
pipx install --force "$SOURCE_DIR/autotiling"
