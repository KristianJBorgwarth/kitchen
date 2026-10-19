import QtQuick
import qs.core

// Magnifier: `span`×`span` px of `source` around `point` at `zoom`×, for lining edges up by
// the pixel, with the coordinates underneath. Sits beside the point, flipping sides at the
// parent's edges.
Rectangle {
    id: root
    required property Item source
    property point point
    property int span: 16
    property int zoom: 8
    readonly property real gap: 24

    width: span * zoom + 2
    height: span * zoom + 2 + 22
    x: point.x + gap + width > parent.width ? point.x - gap - width : point.x + gap
    y: point.y + gap + height > parent.height ? point.y - gap - height : point.y + gap
    radius: Main.radius
    color: Main.theme.colBg
    border.color: Main.theme.colMuted
    border.width: 1

    ShaderEffectSource {
        id: lens
        x: 1
        y: 1
        width: root.span * root.zoom
        height: width
        sourceItem: root.source
        sourceRect: Qt.rect(Math.floor(root.point.x) - root.span / 2, Math.floor(root.point.y) - root.span / 2, root.span, root.span)
        smooth: false
    }
    // the pixel under the point
    Rectangle {
        x: lens.x + root.span / 2 * root.zoom
        y: lens.y + root.span / 2 * root.zoom
        width: root.zoom
        height: root.zoom
        color: "transparent"
        border.color: Main.theme.colFg
        border.width: 1
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: Math.floor(root.point.x) + ", " + Math.floor(root.point.y)
        color: Main.theme.colAccentLight
        font: Main.smallFont
    }
}
