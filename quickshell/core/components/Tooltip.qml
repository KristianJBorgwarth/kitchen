import QtQuick
import Quickshell
import qs.core

// Hover label for its parent: put `Tooltip { text: "Lock" }` inside any item. The bubble
// is lifted to the window's top level so cards that clip can't cut it off, and the
// hover check is a passive HoverHandler, so the parent's own clicks are untouched.
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
        parent: root.QsWindow.window?.contentItem ?? root
        z: 1000
        visible: hover.hovered && !wait.running && root.text !== ""
        width: label.implicitWidth + 16
        height: label.implicitHeight + 10
        radius: Main.radius
        color: Main.theme.colFg

        // above the parent, centered; below it when there's no room; kept inside the window
        function place() {
            const p = root.mapToItem(parent, root.width / 2, 0);
            const below = root.mapToItem(parent, 0, root.height).y + 6;
            x = Math.max(4, Math.min(parent.width - width - 4, p.x - width / 2));
            y = p.y - height - 6 >= 4 ? p.y - height - 6 : below;
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
