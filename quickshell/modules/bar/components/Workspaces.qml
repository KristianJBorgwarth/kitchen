import Quickshell
import Quickshell.I3
import Quickshell.Services.Notifications
import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// Workspaces 1-9 as a fixed row of pips, so each one is always in the same spot: a ring when
// empty, filled when something's on it. The focused one stretches into a bar.
Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property int dotSize: 7
    readonly property int activeSize: 18

    // where the focused workspace's slot is; that slot fills these in, and the others leave
    // them alone when they lose focus (RestoreNone), so the order the old and new one update
    // in doesn't matter. Live bindings, so the pill follows the slot as it opens up
    property real activeX: 0
    property real activeW: 0
    // straight from the list rather than set by the slots: the old one letting go after the
    // new one took over would switch the pill off
    readonly property bool hasActive: I3.workspaces.values.some(w => w.focused && w.number >= 1 && w.number <= 9)
    // no animation on the first layout, only from then on
    property bool placed: false
    Component.onCompleted: Qt.callLater(() => placed = true)

    Rectangle {
        anchors.verticalCenter: row.verticalCenter
        x: root.activeX
        width: root.activeW
        height: root.dotSize
        radius: height / 2
        visible: root.hasActive
        color: Main.theme.colFg
    }

    Row {
        id: row
        spacing: 10

        Repeater {
            model: 9
            Item {
                id: workspace
                required property int index
                readonly property int number: index + 1
                // null while sway doesn't have it: empty and not showing anywhere
                readonly property var ws: I3.workspaces.values.find(w => w.number === number) ?? null
                readonly property bool focused: ws?.focused ?? false
                // showing on the other monitor
                readonly property bool isActive: ws?.active ?? false

                // the app ids on it, from sway's layout string: "H[V[ghostty] brave-browser]"
                readonly property var apps: (ws?.lastIpcObject?.representation ?? "").replace(/[HVTS]?\[|\]/g, " ").split(/\s+/).filter(a => a)
                readonly property bool hasContent: apps.length > 0

                // marked while an app on it asks for attention (sway's urgent), or has sent a
                // notification since the workspace was last looked at: the highest urgency of
                // those notifications, -1 when unmarked
                onFocusedChanged: if (focused)
                    Notifs.seen(number)
                // a workspace sway just created for you is already being looked at
                Component.onCompleted: if (focused)
                    Notifs.seen(number)
                readonly property int level: focused ? -1 : Math.max(Number(Notifs.marks[number] ?? -1), (ws?.urgent ?? false) ? NotificationUrgency.Normal : -1)

                implicitWidth: focused ? root.activeSize : root.dotSize
                implicitHeight: 16
                Behavior on implicitWidth {
                    enabled: root.placed
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                // marked ones by urgency, then the one showing on the other monitor, then in use
                Rectangle {
                    readonly property color tint: workspace.level === NotificationUrgency.Critical ? Main.theme.colRed : workspace.level >= 0 ? Main.theme.colAmber : workspace.isActive ? Main.theme.colFg : workspace.hasContent ? Main.theme.colAccentLight : Main.theme.colMuted
                    anchors.centerIn: parent
                    width: root.dotSize
                    height: root.dotSize
                    radius: width / 2
                    color: workspace.level >= 0 || workspace.isActive || workspace.hasContent ? tint : "transparent"
                    border.width: 1.5
                    border.color: tint
                    opacity: workspace.focused ? 0 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Main.anim * 2
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Main.anim * 2
                        }
                    }
                }

                Binding {
                    when: workspace.focused
                    target: root
                    property: "activeX"
                    value: workspace.x
                    restoreMode: Binding.RestoreNone
                }
                Binding {
                    when: workspace.focused
                    target: root
                    property: "activeW"
                    value: workspace.width
                    restoreMode: Binding.RestoreNone
                }

                HoverChip {
                    visible: !workspace.focused
                }

                // reaches halfway into the gaps on either side, so there's no dead space between
                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: -row.spacing / 2
                    anchors.rightMargin: -row.spacing / 2
                    anchors.topMargin: -6
                    anchors.bottomMargin: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        WorkspacePeek.hide();
                        Windows.focusWorkspace(String(workspace.number));
                    }

                    // a peek at what's on it; not for the one you're on, or an empty one
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered && !workspace.focused && workspace.hasContent)
                                WorkspacePeek.enter(workspace.ws.name, workspace);
                            else
                                WorkspacePeek.leave(String(workspace.number));
                        }
                    }
                }
            }
        }
    }
}
