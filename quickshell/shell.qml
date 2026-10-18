//@ pragma UseQApplication
import Quickshell // for PanelWindow
import QtQuick // for Text
import qs.core // for Scope
import qs.modules.bar

Scope {
    // create the modal overlay up front, so the first open doesn't also create its surface
    readonly property var modalHost: ModalHost

    Bar {}
    Ipc {}
    MusicIpc {}
}
