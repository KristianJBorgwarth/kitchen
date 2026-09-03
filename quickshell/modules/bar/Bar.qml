import Quickshell // for PanelWindow
import Quickshell.I3
import QtQuick // for Text
import qs.core
import "components"

Scope {
    id: root
    PanelWindow {
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 30
        color: Main.theme.colBg

        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            leftPadding: 4
            Workspaces {}
        }

        Row {
            id: centerRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Clock {}
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }
}
