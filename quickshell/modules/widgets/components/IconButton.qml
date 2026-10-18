import QtQuick
import qs.core

// Round icon button. With confirm: true the first click arms it and a second
// click within 3s fires, so reboot/poweroff can't happen by accident.
Rectangle {
    id: root
    property string icon: ""
    property bool confirm: false
    property bool armed: false
    property font iconFont: Main.iconFont
    signal clicked

    implicitWidth: 36
    implicitHeight: 36
    radius: 4
    color: armed ? Main.theme.colFg : (mouse.containsMouse ? Main.theme.colMuted : "transparent")

    Behavior on color {
        ColorAnimation {
            duration: 120
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
