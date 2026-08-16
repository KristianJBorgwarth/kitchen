!#/bin/bash

source /etc/os-release
case "$ID" in
    ubuntu)
      ./ubuntu-install.sh
        ;;
    arch)
      ./arch-install.sh
        ;;
    *)
        echo "Unsupported OS: $ID"
        exit 1
        ;;
esac

./common-install.sh
./symlink.sh

