import Quickshell
import QtQuick
import qs.core
import qs.modules.widgets

Row {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    Text {
        id: memIcon
        text: "󰓅" 
        color: Main.theme.colFg
        font: Main.barFont

        MouseArea {
            anchors.fill: parent
            onClicked: Performance.toggle()
        }
    }
}
