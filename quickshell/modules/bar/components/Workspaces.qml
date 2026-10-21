import Quickshell
import Quickshell.I3
import Quickshell.Services.Notifications
import QtQuick // for Text
import qs.core
import qs.services
import qs.modules.widgets

// The workspaces on one monitor, as sway has them: sway drops an empty workspace once it's
// off screen, so this is what's in use plus whatever is showing. A pill glides to the one
// that's visible here: solid while this monitor has focus, faint otherwise.
Item {
    id: root
    required property var screen
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // the numbered ones, in order; named ones (m, d) are single-purpose and stay off the bar
    readonly property var spaces: I3.workspaces.values.filter(w => w.number >= 0 && w.monitor?.name === screen?.name).sort((a, b) => a.number - b.number)
    readonly property bool focusedHere: I3.focusedMonitor?.name === screen?.name

    // where the visible workspace's label is; that delegate fills these in, and the others
    // leave them alone when they stop being visible (RestoreNone), so the order the old and
    // new one update in doesn't matter
    property real activeX: 0
    property real activeW: 0
    // straight from the list rather than set by the delegates: the old one letting go after
    // the new one took over would switch the pill off
    readonly property bool hasActive: spaces.some(w => w.active)
    // no glide on the first placement, only from then on
    property bool placed: false
    Component.onCompleted: Qt.callLater(() => placed = true)

    Rectangle {
        anchors.verticalCenter: row.verticalCenter
        x: root.activeX - 7
        width: root.activeW + 14
        height: 22
        radius: Main.radius
        visible: root.hasActive
        color: root.focusedHere ? Main.theme.colFg : Main.theme.colMuted

        Behavior on x {
            enabled: root.placed
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            enabled: root.placed
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Main.anim * 2
            }
        }
    }

    Row {
        id: row
        spacing: 15

        Repeater {
            model: root.spaces
            Text {
                id: workspace
                required property var modelData
                readonly property var ws: modelData
                readonly property bool focused: ws.focused
                readonly property bool isActive: ws.active

                // the app ids on it, from sway's layout string: "H[V[ghostty] brave-browser]"
                readonly property var apps: (ws.lastIpcObject?.representation ?? "").replace(/[HVTS]?\[|\]/g, " ").split(/\s+/).filter(a => a)
                readonly property bool hasContent: apps.length > 0

                // marked while an app on it asks for attention (sway's urgent), or has sent a
                // notification since the workspace was last looked at: the highest urgency of
                // those notifications, -1 when unmarked. Notifications are tracked by number,
                // so named workspaces only get sway's urgent
                onFocusedChanged: if (focused && ws.number >= 0)
                    Notifs.seen(ws.number)
                // a workspace sway just created for you is already being looked at
                Component.onCompleted: if (focused && ws.number >= 0)
                    Notifs.seen(ws.number)
                readonly property int level: focused ? -1 : Math.max(ws.number >= 0 ? Number(Notifs.marks[ws.number] ?? -1) : -1, ws.urgent ? NotificationUrgency.Normal : -1)

                // marked ones show the selector's square, colored by urgency
                text: !isActive && level >= 0 ? "" : ws.name
                // dark text only while the pill is there to sit on
                color: isActive ? (root.focusedHere && root.hasActive ? Main.theme.colBg : Main.theme.colFg) : level === NotificationUrgency.Critical ? Main.theme.colRed : level >= 0 ? Main.theme.colAmber : hasContent ? Main.theme.colAccentLight : Main.theme.colMuted
                font: Main.pillFont

                Behavior on color {
                    ColorAnimation {
                        duration: Main.anim * 2
                    }
                }

                Binding {
                    when: workspace.isActive
                    target: root
                    property: "activeX"
                    value: workspace.x
                    restoreMode: Binding.RestoreNone
                }
                Binding {
                    when: workspace.isActive
                    target: root
                    property: "activeW"
                    value: workspace.width
                    restoreMode: Binding.RestoreNone
                }

                HoverChip {
                    visible: !workspace.isActive
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
                        Windows.focusWorkspace(workspace.ws.name);
                    }

                    // a peek at what's on it; not for the one you're on, or an empty one
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered && !workspace.focused && workspace.hasContent)
                                WorkspacePeek.enter(workspace.ws.name, workspace);
                            else
                                WorkspacePeek.leave(workspace.ws.name);
                        }
                    }
                }
            }
        }
    }
}
