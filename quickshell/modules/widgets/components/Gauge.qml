import QtQuick
import QtQuick.Shapes
import QtQuick.Shapes.DesignHelpers
import qs.core

// Radial speedometer-style gauge: a 270° arc track with a value arc on top.
Column {
    id: root
    property real value: 0 // 0-100
    property string label: ""
    property real diameter: 64

    spacing: 4

    Item {
        width: root.diameter
        height: root.diameter
        anchors.horizontalCenter: parent.horizontalCenter

        EllipseShape {
            anchors.fill: parent
            startAngle: -225
            sweepAngle: 270
            innerArcRatio: 0.75
            strokeWidth: 6
            strokeColor: Main.theme.colMuted
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
        }

        EllipseShape {
            startAngle: -225
            sweepAngle: 270 * Math.max(0, Math.min(100, root.value)) / 100
            anchors.fill: parent
            innerArcRatio: 0.75
            strokeWidth: 6
            strokeColor: Main.theme.colAccentLight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            Behavior on sweepAngle {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: Math.round(root.value) + "%"
            color: Main.theme.colFg
            font: Main.barFont
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        color: Main.theme.colFg
        font: Main.barFont
    }
}
