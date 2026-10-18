pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core

// Tray drawer: drops down under the bar's tray button, so the bar never reflows.
Scope {
    id: root
    property bool opened: false
    // the bar's tray button, set by Tray.qml; measured on every open since the bar reflows
    property Item anchorItem: null
    property real anchorX: 0
    property var screen: null

    function show() {
        if (ControlCenter.opened)
            ControlCenter.hide();
        if (MusicPlayer.opened)
            MusicPlayer.hide();
        if (anchorItem) {
            anchorX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
            screen = anchorItem.QsWindow.window.screen;
        }
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

        readonly property int cols: Math.min(4, Math.max(1, SystemTray.items.values.length))
        implicitWidth: grid.implicitWidth + 12
        implicitHeight: grid.implicitHeight + 12

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Main.theme.colBg
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
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        width: 28
                        height: 28
                        radius: 4
                        color: mouse.containsMouse ? Main.theme.colMuted : "transparent"

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
                                const item = cell.modelData;
                                if (mouse.button === Qt.MiddleButton) {
                                    item.secondaryActivate();
                                } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                    if (item.hasMenu) {
                                        const pos = cell.mapToItem(null, 0, cell.height);
                                        item.display(panel, pos.x, pos.y);
                                    }
                                } else {
                                    item.activate();
                                    root.hide();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
