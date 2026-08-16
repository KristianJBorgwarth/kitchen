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

# run common install and setup
./common-install.sh
./symlink.sh


# finalize
