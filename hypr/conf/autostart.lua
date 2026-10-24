hl.on("hyprland.start", function()
    -- quickshell and the portals read these from the systemd/dbus activation environment
    -- one chain, so nothing that needs the portals starts before the environment is in
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE && dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE && exec quickshell")

    -- light/dark (color-scheme, GTK and icon themes) is set by quickshell's theme switch
    -- lock before any sleep (lid, systemctl); -w holds the sleep until the lock is up
    hl.exec_cmd("swayidle -w before-sleep 'qs ipc call lock lock; sleep 0.5'")
    hl.exec_cmd("kanshi")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd('env PATH="$PATH:$HOME/go/bin" wl-paste --type text --watch cliphist store')
    hl.exec_cmd('env PATH="$PATH:$HOME/go/bin" wl-paste --type image --watch cliphist store')
end)
