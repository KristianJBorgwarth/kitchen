import Quickshell.I3
import QtQuick // for Text
import qs.core

Row {
    id: root
    spacing: 15
    Repeater {
        model: 9
        Text {
            id: workspace
            required property int index

            property var ws: I3.workspaces.values.find(w => w.number === index + 1)

            property bool hasContent: {
                const rep = ws?.lastIpcObject?.representation;
                return !!rep && !/\[\s*\]$/.test(rep);
            }

            text: ws?.focused ? "" : index + 1
            color: ws?.focused ? Main.theme.colFg : (hasContent ? Main.theme.colAccentLight : Main.theme.colMuted)

            font {
                family: Main.fontFamily
                pixelSize: 14
            }

            MouseArea {
                anchors.fill: parent
                onClicked: I3.dispatch("workspace " + (workspace.index + 1))
            }
        }
    }
}
