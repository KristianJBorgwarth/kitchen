import QtQuick
import qs.core

// confirm: the first click arms it, a second within 3s fires.
Rectangle {
    id: root
    property string icon: ""
    property bool confirm: false
    property bool armed: false
    property font iconFont: Main.iconFont
    property color armedColor: Main.theme.colFg
    signal clicked

    implicitWidth: 36
    implicitHeight: 36
    radius: 4
    color: armed ? armedColor : (mouse.containsMouse ? Main.theme.colMuted : "transparent")

    Behavior on color {
        ColorAnimation {
            duration: Main.anim
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.armed ? Main.theme.colBg : Main.theme.colFg
        font: root.iconFont
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = false
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.confirm && !root.armed) {
                root.armed = true;
                disarm.restart();
                return;
            }
            root.armed = false;
            root.clicked();
        }
    }
}
