pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Modals live in `stage`, which outlasts the window showing it: the window is made for one
// screen and dropped with it (unplug, undock), and the stage moves into the next one
Scope {
    id: root
    property var current: null
    readonly property bool active: current !== null
    readonly property Item stage: stage

    // where modals show: the focused monitor when the last one opened
    property string screenName: Compositor.focusedMonitor
    readonly property var screen: Main.screens.find(s => s.name === screenName) ?? Main.screens[0] ?? null

    signal opening

    function open(modal) {
        opening();
        if (Compositor.focusedMonitor !== "")
            screenName = Compositor.focusedMonitor;
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

    Item {
        id: stage
        width: parent?.width ?? 0
        height: parent?.height ?? 0
    }

    Variants {
        model: root.screen ? [root.screen] : []

        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
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
            WlrLayershell.keyboardFocus: !root.active ? WlrKeyboardFocus.None : root.grabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

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

            // above the backdrop; handed back before this window goes, so the modals survive it
            Component.onCompleted: stage.parent = window.contentItem
            Component.onDestruction: if (stage.parent === window.contentItem) stage.parent = null
        }
    }
}
