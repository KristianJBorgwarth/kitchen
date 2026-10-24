import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.core
import qs.core.components

// One monitor's layer for Draw: the drawings over the live screen and, while drawing, a
// frame in the ink colour round the monitor and the tool bar. Pinned, it takes no input.
// `draw` is the Draw singleton.
PanelWindow {
    id: win
    required property var modelData
    required property var draw
    readonly property bool focusedScreen: modelData.name === (Compositor.focusedMonitor ?? "")

    screen: modelData
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-draw"
    WlrLayershell.keyboardFocus: draw.active && focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: draw.active ? null : passThrough

    Region {
        id: passThrough
    }

    Connections {
        target: win.draw
        function onActiveChanged() {
            if (win.draw.active)
                stage.forceActiveFocus();
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => keys.handle(event)

        Sketch {
            anchors.fill: parent
            owner: win.draw
            screen: win.modelData.name
            interactive: win.draw.active
            onRightClicked: win.draw.exit()
        }

        // so it's clear the screen is being drawn on, not used
        Rectangle {
            anchors.fill: parent
            visible: win.draw.active
            color: "transparent"
            border.color: win.draw.ink
            border.width: 2
        }

        Rectangle {
            visible: win.draw.active && win.focusedScreen
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            width: bar.implicitWidth + 16
            height: bar.implicitHeight + 16
            radius: Main.radius
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1

            Row {
                id: bar
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 6
                    rightPadding: 6
                    text: "󰏫"
                    color: Main.theme.colFg
                    font: Main.iconFont
                }
                DrawingTools {
                    anchors.verticalCenter: parent.verticalCenter
                    owner: win.draw
                }
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "<b>c</b>  clear"
                    clickable: true
                    onClicked: win.draw.clear()
                }
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "<b>Space</b>  pin"
                    clickable: true
                    onClicked: win.draw.pin()
                }
                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "<b>Esc</b>"
                    clickable: true
                    onClicked: win.draw.exit()
                }
            }
        }

        KeyHelp {
            vimKeys: keys
        }
    }

    VimKeys {
        id: keys
        bindings: win.draw.tools.map(t => ({ keys: t.key, desc: t.label, run: () => win.draw.setTool(t.id) })).concat(win.draw.inks.map((ink, i) => ({ keys: String(i + 1), desc: ink.name, run: () => win.draw.ink = ink.color })), [
            { keys: "u", desc: "undo", run: () => win.draw.undo() },
            { keys: "<C-z>", desc: "", run: () => win.draw.undo() },
            { keys: "c", desc: "clear", run: () => win.draw.clear() },
            { keys: "<Space>", desc: "pin: keep the drawings, use the screen", run: () => win.draw.pin() },
            { keys: "<Esc>", desc: "clear and stop", run: () => win.draw.exit() },
            { keys: "q", desc: "", run: () => win.draw.exit() }
        ])
    }
}
