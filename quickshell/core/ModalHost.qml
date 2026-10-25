pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root
    property var current: null
    readonly property bool active: current !== null
    readonly property Item stage: stage

    signal opening

    function open(modal) {
        if (current && current !== modal)
            current.hide();
        opening();
        const focused = Quickshell.screens.find(s => s.name === Compositor.focusedMonitor);
        if (focused && screen !== focused)
            screen = focused;
        current = modal;
    }

    function release(modal) {
        if (current === modal)
            current = null;
    }

    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
        item: root.active ? backdrop : null
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-modal"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        id: backdrop
        anchors.fill: parent
        // keyboard focus is exclusive while open, so a press anywhere outside the card closes it
        color: Qt.rgba(0, 0, 0, root.active ? root.current.dim : 0)

        Behavior on color {
            ColorAnimation {
                duration: Main.anim
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: root.current?.hide()
        }
    }

    Item {
        id: stage
        anchors.fill: parent
    }
}
