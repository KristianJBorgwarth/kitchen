//@ pragma UseQApplication
import Quickshell // for PanelWindow
import QtQuick // for Text
import qs.core // for Scope
import qs.services
import qs.modules.bar
import qs.modules.widgets

Scope {
    readonly property var modalHost: ModalHost
    readonly property var switcher: Switcher
    readonly property var wallpaper: Wallpaper
    // writes ghostty / sway / k9s colors from the palette
    readonly property var themeExport: ThemeExport
    Bar {}
    NotificationPopups {}
    Idle {}
    Ipc {}
    MusicIpc {}
}
