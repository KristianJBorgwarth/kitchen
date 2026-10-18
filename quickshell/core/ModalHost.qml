pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland

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
        const focused = Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name);
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
        color: "black"
        opacity: root.active ? 0.5 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Main.anim
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.current?.hide()
        }
    }

    Item {
        id: stage
        anchors.fill: parent
    }
}
