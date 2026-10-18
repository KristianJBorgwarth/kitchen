import QtQuick
import qs.core

Rectangle {
    id: root
    property bool checked: false
    property color accent: Main.theme.colFg
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    radius: Main.radius
    color: checked ? accent : Main.theme.colMuted

    Behavior on color {
        ColorAnimation {
            duration: Main.anim
        }
    }

    Rectangle {
        x: root.checked ? root.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: root.height - 6
        height: width
        radius: Main.radius - 1
        color: root.checked ? Main.theme.colBg : Main.theme.colFg

        Behavior on x {
            NumberAnimation {
                duration: Main.anim
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
