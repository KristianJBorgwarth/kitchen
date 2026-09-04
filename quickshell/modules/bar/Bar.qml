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
        implicitHeight: 38
        color: "transparent"

        Rectangle {
            id: leftPill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            radius: 4
            color: Main.theme.colBg
            height: 25
            width: leftRow.implicitWidth + 16

            Row {
                id: leftRow
                anchors.centerIn: parent
                spacing: 4
                Workspaces {}
            }
        }

        Rectangle {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: Main.theme.colBg
            height: 25
            width: centerRow.implicitWidth + 16

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 8
                Clock {}
            }
        }

        Rectangle {
            id: rightPill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            radius: 4
            color: Main.theme.colBg
            height: 25
            width: rightRow.implicitWidth + 16

            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: 20
                Resources {}
                Tray {}
            }
        }
    }
}
