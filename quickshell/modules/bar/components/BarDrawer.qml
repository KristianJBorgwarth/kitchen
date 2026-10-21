import QtQuick
import qs.core

// Slides out to the left of the item after it in a Row (volume's level bar, battery's details,
// the power actions). It opens to its content plus `gap`, the space to that item, so nothing
// pops at either end; the content keeps its full size, pinned right, so it's revealed rather
// than squeezed.
//
// Set `hovered` and it opens once the mouse rests on the widget, so passing over on the way
// somewhere else doesn't push the bar around, and closes after a short grace period. `open`
// can also be set directly (a scroll); with `followHover: false` it's only ever set directly.
Item {
    id: root
    default property alias content: inner.data
    property bool open: false
    property bool hovered: false
    property bool followHover: true
    property int gap: 10

    anchors.verticalCenter: parent.verticalCenter
    height: inner.implicitHeight
    width: open ? inner.implicitWidth + gap : 0
    opacity: open ? 1 : 0
    visible: width > 0
    clip: true

    Timer {
        interval: 150
        running: root.followHover && !root.open && root.hovered
        onTriggered: root.open = true
    }
    Timer {
        interval: 400
        running: root.followHover && root.open && !root.hovered
        onTriggered: root.open = false
    }

    // out with a soft landing, back in a little quicker
    Behavior on width {
        NumberAnimation {
            duration: root.open ? 220 : 160
            easing.type: root.open ? Easing.OutCubic : Easing.InCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? 220 : 120
        }
    }

    Row {
        id: inner
        anchors.right: parent.right
        anchors.rightMargin: root.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap
    }
}
