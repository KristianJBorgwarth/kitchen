pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.core.components

// Tray drawer: drops down under the bar's tray button, so the bar never reflows.
Scope {
    id: root
    property bool opened: false
    // the bar's tray button, set by Tray.qml; measured on every open since the bar reflows
    property Item anchorItem: null
    property real anchorX: 0
    property var screen: null
    // keyboard selection (h/j/k/l), reset on every open
    property int selected: 0

    function show() {
        if (ControlCenter.opened)
            ControlCenter.hide();
        if (MusicPlayer.opened)
            MusicPlayer.hide();
        if (anchorItem) {
            anchorX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
            screen = anchorItem.QsWindow.window.screen;
        }
        selected = 0;
        unmapTimer.stop();
        panel.visible = true;
        opened = true;
    }

    function hide() {
        opened = false;
        unmapTimer.restart();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    Timer {
        id: unmapTimer
        interval: 220
        onTriggered: {
            if (!root.opened)
                panel.visible = false;
        }
    }

    // invisible full-screen catcher so a click anywhere else closes the drawer
    PanelWindow {
        visible: root.opened
        screen: root.screen
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-tray-backdrop"

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    PanelWindow {
        id: panel
        visible: false
        screen: root.screen
        color: "transparent"
        anchors.top: true
        anchors.left: true
        exclusiveZone: 0
        margins.top: 4
        margins.left: Math.max(6, Math.min((screen?.width ?? 0) - implicitWidth - 6, root.anchorX - implicitWidth / 2))
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-tray"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property int cols: Math.min(4, Math.max(1, SystemTray.items.values.length))
        implicitWidth: grid.implicitWidth + 12
        implicitHeight: grid.implicitHeight + 12

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Main.theme.colBg
            focus: true
            Keys.onPressed: event => vimKeys.handle(event)

            VimKeys {
                id: vimKeys
                readonly property int count: SystemTray.items.values.length
                function move(d) {
                    if (count > 0)
                        root.selected = Math.max(0, Math.min(count - 1, root.selected + d));
                }
                function current() {
                    return SystemTray.items.values[root.selected];
                }
                bindings: [
                    { keys: "h", desc: "left", run: () => move(-1) },
                    { keys: "l", desc: "right", run: () => move(1) },
                    { keys: "k", desc: "up", run: () => move(-panel.cols) },
                    { keys: "j", desc: "down", run: () => move(panel.cols) },
                    { keys: "<CR>", desc: "activate", run: () => cells.itemAt(root.selected)?.activate() },
                    { keys: "o", desc: "", run: () => cells.itemAt(root.selected)?.activate() },
                    { keys: "m", desc: "menu", run: () => cells.itemAt(root.selected)?.openMenu() },
                    { keys: "q", desc: "close", run: () => root.hide() },
                    { keys: "<Esc>", desc: "", run: () => root.hide() }
                ]
            }
            border.color: Main.theme.colMuted
            border.width: 1

            transformOrigin: Item.Top
            scale: root.opened ? 1 : 0
            opacity: root.opened ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Grid {
                id: grid
                anchors.centerIn: parent
                columns: panel.cols
                spacing: 2

                Repeater {
                    id: cells
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        width: 28
                        height: 28
                        radius: 4
                        color: mouse.containsMouse ? Main.theme.colMuted : "transparent"
                        border.color: root.selected === index ? Main.theme.colAccentMid : "transparent"
                        border.width: 1

                        function activate() {
                            if (modelData.onlyMenu) {
                                openMenu();
                                return;
                            }
                            modelData.activate();
                            root.hide();
                        }

                        function openMenu() {
                            if (!modelData.hasMenu)
                                return;
                            const pos = cell.mapToItem(null, 0, cell.height);
                            modelData.display(panel, pos.x, pos.y);
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 16
                            source: cell.modelData.icon
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                root.selected = cell.index;
                                if (mouse.button === Qt.MiddleButton)
                                    cell.modelData.secondaryActivate();
                                else if (mouse.button === Qt.RightButton)
                                    cell.openMenu();
                                else
                                    cell.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
