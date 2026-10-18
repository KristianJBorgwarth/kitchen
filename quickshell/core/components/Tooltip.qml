import QtQuick
import Quickshell
import qs.core

// Hover label for its parent: put `Tooltip { text: "Lock" }` inside any item. The hover check
// is a passive HoverHandler, so the parent's own clicks are untouched. The bubble stays inside
// the parent: lifting it to the window's top level crashed quickshell when that window moved
// to another monitor (the bubble kept pointing at the old, destroyed window).
Item {
    id: root
    property string text: ""
    property int delay: 450

    anchors.fill: parent

    HoverHandler {
        id: hover
    }

    Timer {
        id: wait
        interval: root.delay
        running: hover.hovered && root.text !== ""
        onTriggered: bubble.place()
    }

    Rectangle {
        id: bubble
        z: 1000
        visible: hover.hovered && !wait.running && root.text !== ""
        width: label.implicitWidth + 16
        height: label.implicitHeight + 10
        radius: Main.radius
        color: Main.theme.colFg

        // above the parent, centered; below it when the window has no room above
        function place() {
            x = (root.width - width) / 2;
            y = root.mapToItem(null, 0, 0).y - height - 6 >= 4 ? -height - 6 : root.height + 6;
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Main.theme.colBg
            font: Main.smallFont
        }
    }
}
