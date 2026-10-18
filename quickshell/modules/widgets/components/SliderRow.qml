import QtQuick
import qs.core

// Icon + draggable bar + percentage. Click the icon for the secondary action (mute).
Item {
    id: root
    property string icon: ""
    property real value: 0
    property bool dimmed: false
    signal moved(real value)
    signal iconClicked

    implicitHeight: 28

    Text {
        id: iconText
        width: 24
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.dimmed ? Main.theme.colAccentDark : Main.theme.colFg
        font: Main.iconFont

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    Text {
        id: pct
        width: 36
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        color: root.dimmed ? Main.theme.colAccentDark : Main.theme.colFg
        font: Main.barFont
    }

    Item {
        id: track
        anchors.left: iconText.right
        anchors.leftMargin: 8
        anchors.right: pct.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Main.theme.colMuted

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.value))
                height: parent.height
                radius: 3
                color: root.dimmed ? Main.theme.colAccentDark : Main.theme.colAccentLight

                Behavior on width {
                    enabled: !drag.pressed
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }

        Rectangle {
            x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: drag.pressed || drag.containsMouse ? 14 : 10
            height: width
            radius: width / 2
            color: Main.theme.colFg

            Behavior on width {
                NumberAnimation {
                    duration: 100
                }
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function emit(x) {
                root.moved(Math.max(0, Math.min(1, x / track.width)));
            }
            onPressed: mouse => emit(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    emit(mouse.x);
            }
            onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
}
