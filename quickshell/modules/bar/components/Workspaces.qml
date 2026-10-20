import Quickshell.I3
import Quickshell.Services.Notifications
import QtQuick // for Text
import qs.core
import qs.services

Row {
    id: root
    spacing: 15
    Repeater {
        model: 9
        Text {
            id: workspace
            required property int index

            property var ws: I3.workspaces.values.find(w => w.number === index + 1)
            readonly property bool focused: ws?.focused ?? false

            // the app ids on it, from sway's layout string: "H[V[ghostty] brave-browser]"
            readonly property var apps: (ws?.lastIpcObject?.representation ?? "").replace(/[HVTS]?\[|\]/g, " ").split(/\s+/).filter(a => a)
            readonly property bool hasContent: apps.length > 0

            // marked while an app on it asks for attention (sway's urgent), or has sent a
            // notification since the workspace was last looked at: the highest urgency of
            // those notifications, -1 when unmarked
            onFocusedChanged: if (focused)
                Notifs.seen(index + 1)
            readonly property int level: focused ? -1 : Math.max(Number(Notifs.marks[index + 1] ?? -1), (ws?.urgent ?? false) ? NotificationUrgency.Normal : -1)

            // marked ones show the selector's square, colored by urgency
            text: focused || level >= 0 ? "" : index + 1
            color: focused ? Main.theme.colFg : level === NotificationUrgency.Critical ? Main.theme.colRed : level >= 0 ? Main.theme.colAmber : hasContent ? Main.theme.colAccentLight : Main.theme.colMuted

            font: Main.pillFont
            MouseArea {
                anchors.fill: parent
                onClicked: I3.dispatch("workspace " + (workspace.index + 1))
            }
        }
    }
}
