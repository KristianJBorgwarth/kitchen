import Quickshell.I3
import QtQuick // for Text
import qs.core

Row {
    id: root
    spacing: 11
    Repeater {
        model: 9
        Text {
            id: workspace
            required property int index

            property var ws: I3.workspaces.values.find(w => w.number === index + 1)
            text: index + 1
            color: ws?.focused ? Main.theme.colFg : (ws ? Main.theme.colAccentLight : Main.theme.colMuted)

            font {
                family: "Jetbrains Mono Nerd Font"
                pixelSize: 14
            }

            MouseArea {
                anchors.fill: parent
                onClicked: I3.dispatch("workspace " + (workspace.index + 1))
            }
        }
    }
}
