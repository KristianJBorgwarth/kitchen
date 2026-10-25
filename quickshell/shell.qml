//@ pragma UseQApplication
//@ pragma NativeTextRendering
import Quickshell // for PanelWindow
import QtQuick // for Text
import Quickshell.Services.SystemTray
import qs.core // for Scope
import qs.services
import qs.modules.bar
import qs.modules.widgets

Scope {
    readonly property var modalHost: ModalHost
    readonly property var switcher: Switcher
    readonly property var wallpaper: Wallpaper
    readonly property var screenshot: Screenshot
    readonly property var draw: Draw
    // writes ghostty / hyprland / k9s colors from the palette
    readonly property var themeExport: ThemeExport
    // owns the tray watcher from login: apps like Proton VPN only add a tray icon if one exists
    readonly property var tray: SystemTray
    Bar {}
    NotificationPopups {}
    Idle {}
    Ipc {}
    MusicIpc {}
}
