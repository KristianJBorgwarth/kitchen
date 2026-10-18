import QtQuick
import qs.core

// Quick-settings tile: icon + label + state line, inverted when active.
Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool clickable: true
    signal clicked

    implicitHeight: 52
    radius: 4
    color: active ? Main.theme.colFg : (mouse.containsMouse && clickable ? Main.theme.colMuted : Main.theme.colSurface)

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.active ? Main.theme.colBg : Main.theme.colFg
            font: Main.iconFont
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            Text {
                width: parent.width
                text: root.label
                color: root.active ? Main.theme.colBg : Main.theme.colFg
                font: Main.barFont
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.sublabel
                color: root.active ? Main.theme.colAccentDark : Main.theme.colAccentMid
                font: Main.smallFont
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.clickable) root.clicked()
    }
}
