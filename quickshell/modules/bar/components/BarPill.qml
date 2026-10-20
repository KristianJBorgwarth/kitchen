import QtQuick
import qs.core

// One island on the bar, sized to what's in it. Children go in a Row; set `shown` to fade and
// shrink it away (it stays laid out while it animates, then hides).
Rectangle {
    id: root
    default property alias content: row.data
    property alias spacing: row.spacing
    property bool shown: true

    readonly property int padding: 14

    anchors.bottom: parent.bottom
    height: 30
    width: row.implicitWidth + padding * 2
    radius: Main.radius
    color: Main.theme.colBg
    border.color: Main.theme.overlay(0.06)
    border.width: 1
    clip: true

    visible: opacity > 0
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.8

    Behavior on opacity {
        NumberAnimation {
            duration: Main.anim
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Main.anim
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Main.anim
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
    }
}
