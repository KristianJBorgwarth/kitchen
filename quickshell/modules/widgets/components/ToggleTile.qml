import QtQuick
import qs.core

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool clickable: true
    property bool hasDetails: false
    signal clicked
    signal detailsClicked

    implicitHeight: 76
    radius: Main.radius
    // on: solid inverted; off: a faint fill
    color: active ? (body.containsMouse ? Qt.tint(Main.theme.colFg, Qt.rgba(Main.theme.colBg.r, Main.theme.colBg.g, Main.theme.colBg.b, 0.12)) : Main.theme.colFg) : (body.containsMouse && clickable ? Main.theme.overlay(0.08) : Main.theme.overlay(0.04))
    scale: body.pressed ? 0.97 : 1

    Behavior on color {
        ColorAnimation {
            duration: Main.anim
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Main.anim
        }
    }

    readonly property color ink: active ? Main.theme.colBg : Main.theme.colFg

    Rectangle {
        id: disc
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 42
        radius: Main.radius
        color: root.active ? Main.theme.colBg : Main.theme.overlay(0.06)

        Behavior on color {
            ColorAnimation {
                duration: Main.anim
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Main.theme.colFg : Main.theme.colAccentLight
            font: Main.iconFont
        }
    }

    Column {
        anchors.left: disc.right
        anchors.leftMargin: 12
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        Text {
            width: parent.width
            text: root.label
            color: root.ink
            font.family: Main.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.sublabel
            color: root.active ? Qt.tint(Main.theme.colBg, Qt.rgba(Main.theme.colFg.r, Main.theme.colFg.g, Main.theme.colFg.b, 0.45)) : Main.theme.colAccentMid
            font: Main.smallFont
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.clickable) root.clicked()
    }

    Rectangle {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: root.hasDetails ? 28 : 0
        height: 44
        radius: Main.radius
        visible: root.hasDetails
        color: chevMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1) : "transparent"

        Text {
            anchors.centerIn: parent
            text: "󰅂"
            color: root.ink
            font: Main.barFont
        }
        MouseArea {
            id: chevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailsClicked()
        }
    }
}
