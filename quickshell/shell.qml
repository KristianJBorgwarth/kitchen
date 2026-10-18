//@ pragma UseQApplication
import Quickshell // for PanelWindow
import QtQuick // for Text
import qs.core // for Scope
import qs.modules.bar
import qs.modules.widgets

Scope {
    readonly property var modalHost: ModalHost
    readonly property var switcher: Switcher
    // loads its launch stats (and the one-time rofi import) before the first open
    readonly property var launcher: Launcher
    Bar {}
    NotificationPopups {}
    Ipc {}
    MusicIpc {}
}
