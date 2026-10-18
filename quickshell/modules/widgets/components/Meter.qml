import QtQuick
import qs.core

// Thin horizontal bar. segments: [{value, color}] stacked left to right, out of max.
Rectangle {
    id: root
    property real max: 100
    property var segments: []

    implicitHeight: 6
    radius: height / 2
    color: Main.theme.colMuted
    clip: true

    Row {
        anchors.fill: parent
        Repeater {
            model: root.segments
            Rectangle {
                required property var modelData
                height: root.height
                width: root.max > 0 ? root.width * Math.max(0, Math.min(1, modelData.value / root.max)) : 0
                color: modelData.color

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
