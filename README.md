# kitchen
This will contain my final dotfile config, and then I need to stop. 

## Sessions

Sway is the main session, Hyprland is installed next to it and picked at the login screen.
The quickshell config detects which one it runs under (`services/Compositor.qml`).

### Hyprland on Ubuntu

Ubuntu's archive lags upstream (26.04 has 0.53.3, Arch has 0.56.x), and there is no official
apt repo. `install/hyprland-debs.sh` takes the prebuilt packages of the community PPA
`ppa:cppiber/hyprland` (the whole hypr* stack for the current Ubuntu series) straight from
Launchpad and installs them with `sudo apt-get install`. It needs no `add-apt-repository` and no
root beyond that, so it works where sudo is restricted.

- Run it again to update: it installs only when a package is newer than the installed one.
  `--check` just reports. `ubuntu-install.sh` also enables a daily user timer
  (`install/systemd/hyprland-update.*`) that sends a notification when there is an update.
- Updates are not applied by `apt upgrade`, since the PPA isn't added. On Arch a normal system
  update does it.
- Upstream only supports Arch and Nix, so Ubuntu is best effort: the PPA has one maintainer and
  can trail a release or skip a new Ubuntu series. Sway stays installed as the fallback.
