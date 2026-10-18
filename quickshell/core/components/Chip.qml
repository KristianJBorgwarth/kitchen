import QtQuick
import qs.core

Rectangle {
    id: root
    property string text: ""
    property bool active: false
    property bool filled: false
    property bool clickable: false
    property color tint: Main.theme.colFg
    property font font: Main.smallFont
    property real maxWidth: Infinity
    property real padding: 11
    readonly property bool hovered: mouse.containsMouse
    signal clicked

    implicitHeight: 24
    implicitWidth: Math.min(maxWidth, label.implicitWidth + padding * 2)
    radius: Main.radius
    color: active ? (filled ? tint : Qt.rgba(tint.r, tint.g, tint.b, 0.18)) : (hovered && clickable ? Main.theme.overlay(0.1) : Main.theme.overlay(0.04))
    border.color: active && !filled ? tint : Main.theme.overlay(0.08)
    border.width: 1

    Behavior on color {
        ColorAnimation {
            duration: Main.anim
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.maxWidth - root.padding * 2)
        text: root.text
        textFormat: Text.StyledText
        color: root.active ? (root.filled ? Main.theme.colBg : root.tint) : Main.theme.colAccentLight
        font: root.font
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
