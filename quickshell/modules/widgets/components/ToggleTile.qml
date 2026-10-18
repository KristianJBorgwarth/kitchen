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
    property color accent: Main.theme.colFg
    signal clicked
    signal detailsClicked

    implicitHeight: 76
    radius: 14
    color: active ? Qt.rgba(accent.r, accent.g, accent.b, body.containsMouse ? 0.22 : 0.16) : (body.containsMouse && clickable ? Qt.lighter(Main.theme.colSurface, 1.35) : Main.theme.colSurface)
    border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.45) : Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
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

    readonly property color ink: Main.theme.colFg

    Rectangle {
        id: disc
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 42
        radius: 21
        color: root.active ? root.accent : Qt.rgba(1, 1, 1, 0.06)

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Main.theme.colBg : Main.theme.colAccentLight
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
            color: root.active ? root.accent : Main.theme.colAccentMid
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
        radius: 8
        visible: root.hasDetails
        color: chevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

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
