import QtQuick
import qs.core

// The hover highlight for a clickable bar item: put `HoverChip {}` inside it. It sits behind
// its parent, a little larger, and tracks the hover itself (a passive HoverHandler, so the
// parent's MouseArea is untouched).
Rectangle {
    property int padX: 6
    property int padY: 3

    anchors.fill: parent
    anchors.leftMargin: -padX
    anchors.rightMargin: -padX
    anchors.topMargin: -padY
    anchors.bottomMargin: -padY
    z: -1
    radius: Main.radius
    color: Main.theme.overlay(hover.hovered ? 0.1 : 0)

    Behavior on color {
        ColorAnimation {
            duration: Main.anim * 2
        }
    }

    HoverHandler {
        id: hover
    }
}
