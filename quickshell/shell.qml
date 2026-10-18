//@ pragma UseQApplication
import Quickshell // for PanelWindow
import QtQuick // for Text
import qs.core // for Scope
import qs.modules.bar
import qs.modules.widgets

Scope {
    readonly property var modalHost: ModalHost
    readonly property var switcher: Switcher
    Bar {}
    NotificationPopups {}
    Ipc {}
    MusicIpc {}
}
