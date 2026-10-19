import QtQuick
import qs.core
import qs.core.components

// Dims everything but `target`, outlines it and labels its size. Eases from one target to
// the next unless `instant`; an empty target is a point, so the light grows out of it.
Item {
    id: root
    property rect target: Qt.rect(0, 0, 0, 0)
    property bool instant: false
    // outlined as the selection rather than a hover
    property bool selected: false
    readonly property color shade: Qt.rgba(0, 0, 0, 0.5)

    property rect spot: target
    Behavior on spot {
        enabled: !root.instant
        PropertyAnimation {
            duration: Main.anim
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        width: parent.width
        height: root.spot.y
        color: root.shade
    }
    Rectangle {
        y: root.spot.y + root.spot.height
        width: parent.width
        height: parent.height - y
        color: root.shade
    }
    Rectangle {
        y: root.spot.y
        width: root.spot.x
        height: root.spot.height
        color: root.shade
    }
    Rectangle {
        x: root.spot.x + root.spot.width
        y: root.spot.y
        width: parent.width - x
        height: root.spot.height
        color: root.shade
    }

    Rectangle {
        x: root.spot.x - 1
        y: root.spot.y - 1
        width: root.spot.width + 2
        height: root.spot.height + 2
        visible: root.spot.width > 1
        color: "transparent"
        border.color: root.selected ? Main.theme.colBlue : Main.theme.colAccentLight
        border.width: 2
        radius: 2
    }

    // below the spot, or above it at the bottom edge
    Chip {
        readonly property real below: root.spot.y + root.spot.height + 8
        visible: root.target.width > 0
        x: Math.max(0, Math.min(parent.width - width, root.spot.x))
        y: below + height > parent.height ? Math.max(0, root.spot.y - height - 8) : below
        color: Main.theme.colBg
        text: Math.round(root.target.width) + " × " + Math.round(root.target.height)
    }
}
