import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.services

Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 8

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                visible: Focus.icon !== ""
                source: Focus.icon ? Quickshell.iconPath(Focus.icon, true) : ""
            }
            Text {
                anchors.centerIn: parent
                visible: Focus.icon === ""
                text: Focus.glyph
                color: Main.theme.colFg
                font: Main.barFont
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Focus.name
            color: Main.theme.colFg
            font: Main.barFont
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            width: Math.min(implicitWidth, 260)
            text: Focus.detail
            color: Main.theme.colAccentMid
            font: Main.barFont
            elide: Text.ElideRight
        }
    }
}
