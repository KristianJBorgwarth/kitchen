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
        opening();
        const focused = Quickshell.screens.find(s => s.name === Compositor.focusedMonitor);
        if (focused && screen !== focused)
            screen = focused;
        // switch before hiding the old one, so `active` never dips to false in between
        const previous = current;
        current = modal;
        if (previous && previous !== modal)
            previous.hide();
    }

    function release(modal) {
        if (current === modal)
            current = null;
    }

    property bool grabbing: false
    onActiveChanged: {
        Compositor.clickToFocus(active);
        grabbing = active;
        if (active)
            grabEnd.restart();
    }
    Timer {
        id: grabEnd
        interval: 200
        onTriggered: root.grabbing = false
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
        item: root.active ? root.current.card : null
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-modal"
    WlrLayershell.keyboardFocus: !active ? WlrKeyboardFocus.None : grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.active ? root.current.dim : 0)

        Behavior on color {
            ColorAnimation {
                duration: Main.anim
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
    }
}
