import QtQuick
import qs.core
import qs.services

// Shown while stay-awake is on; click to turn it off.
Text {
    anchors.verticalCenter: parent.verticalCenter
    visible: Awake.enabled
    text: "󰈈"
    color: Main.theme.colFg
    font: Main.pillFont

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Awake.enabled = false
    }
}
