pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.services

// Resting on a workspace number in the bar drops a card under it: the switcher's snapshot of
// that workspace (refreshed every few seconds and on every switch) and its windows; click one
// to focus it. Once open, moving along the numbers glides the card over without the delay.
// The window is a full-width strip masked to the card, so the card can move inside it.
Scope {
    id: root
    property bool opened: false
    property int num: -1
    property real anchorX: 0
    property var screen: null

    // the number under the mouse while the open delay runs
    property int pending: -1
    property Item pendingItem: null
    // the number the mouse is on, -1 for none. Moving between numbers can deliver the new
    // one's enter before the old one's leave, so a leave only counts for the current number
    property int hovered: -1

    readonly property var ws: Windows.workspaces.find(w => w.num === num) ?? null
    readonly property var windows: ws?.windows ?? []
    readonly property var snap: ws ? (Switcher.snapshots[ws.name] ?? null) : null

    function enter(n: int, item: Item): void {
        hovered = n;
        closeDelay.stop();
        if (opened) {
            place(n, item);
            return;
        }
        pending = n;
        pendingItem = item;
        // fetch the tree now, so the list is there when the card opens
        Windows.peeking = true;
        openDelay.restart();
    }

    function leave(n: int): void {
        if (hovered !== n)
            return;
        hovered = -1;
        openDelay.stop();
        closeDelay.restart();
    }

    function hide(): void {
        openDelay.stop();
        opened = false;
        Windows.peeking = false;
        unmap.restart();
    }

    function place(n: int, item: Item): void {
        num = n;
        anchorX = item.mapToItem(null, item.width / 2, 0).x;
        screen = item.QsWindow.window.screen;
    }

    Timer {
        id: openDelay
        interval: 350
        onTriggered: {
            if (!root.pendingItem)
                return;
            root.place(root.pending, root.pendingItem);
            unmap.stop();
            panel.visible = true;
            root.opened = true;
        }
    }
    // a short grace period, so the mouse can cross from the number down onto the card
    Timer {
        id: closeDelay
        interval: 200
        onTriggered: if (root.hovered < 0 && !cardHover.hovered) root.hide()
    }
    Timer {
        id: unmap
        interval: Main.anim * 4
        onTriggered: panel.visible = false
    }

    PanelWindow {
        id: panel
        visible: false
        screen: root.screen
        color: "transparent"
        anchors.top: true
        anchors.left: true
        anchors.right: true
        exclusiveZone: 0
        margins.top: 4
        implicitHeight: card.height + 8
        mask: Region {
            item: card
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-workspace-peek"

        Rectangle {
            id: card
            width: 320
            height: content.implicitHeight + 20
            x: Math.max(6, Math.min(panel.width - width - 6, root.anchorX - width / 2))
            y: root.opened ? 0 : -6
            radius: Main.radius
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1
            opacity: root.opened ? 1 : 0

            Behavior on x {
                enabled: root.opened
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Main.anim * 4
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Main.anim * 3
                }
            }

            HoverHandler {
                id: cardHover
                onHoveredChanged: if (!hovered) closeDelay.restart()
            }

            Column {
                id: content
                x: 10
                y: 10
                width: parent.width - 20
                spacing: 8

                Text {
                    text: "Workspace " + root.num + "  ·  " + root.windows.length + (root.windows.length === 1 ? " window" : " windows")
                    color: Main.theme.colAccentMid
                    font: Main.smallFont
                }

                Image {
                    visible: root.snap !== null
                    width: parent.width
                    height: implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
                    source: root.snap?.url ?? ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                Repeater {
                    model: root.windows
                    Rectangle {
                        id: entry
                        required property var modelData
                        width: content.width
                        height: 28
                        radius: Main.radius
                        color: entryMouse.containsMouse ? Main.theme.overlay(0.08) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Main.anim * 2
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 16
                                source: entry.modelData.icon ? Quickshell.iconPath(entry.modelData.icon, true) : ""
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24
                                text: entry.modelData.title || entry.modelData.appId
                                color: Main.theme.colFg
                                font: Main.barFont
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Windows.focusWindow(entry.modelData.id);
                                root.hide();
                            }
                        }
                    }
                }
            }
        }
    }
}
