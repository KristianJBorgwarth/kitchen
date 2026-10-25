import QtQuick
import qs.core

// A settings row: icon, label and state, a switch. hasDetails adds a chevron that opens more.
Item {
    id: root
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool clickable: true
    property bool hasDetails: false
    signal clicked
    signal detailsClicked

    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        radius: Main.radius
        color: mouse.containsMouse && (root.clickable || root.hasDetails) ? Main.theme.overlay(0.05) : "transparent"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable || root.hasDetails ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clickable ? root.clicked() : root.hasDetails && root.detailsClicked()
    }

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        horizontalAlignment: Text.AlignHCenter
        text: root.icon
        color: root.active ? Main.theme.colFg : Main.theme.colAccentDark
        font.family: Main.fontFamily
        font.pixelSize: 16
    }

    Text {
        id: label
        anchors.left: glyph.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Main.theme.colFg
        font: Main.barFont
    }

    Text {
        anchors.left: label.right
        anchors.leftMargin: 10
        anchors.right: chevron.visible ? chevron.left : toggle.left
        anchors.rightMargin: 10
        anchors.baseline: label.baseline
        text: root.sublabel
        color: Main.theme.colAccentMid
        font: Main.smallFont
        elide: Text.ElideRight
    }

    Text {
        id: chevron
        visible: root.hasDetails
        anchors.right: toggle.visible ? toggle.left : parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅂"
        color: chevronMouse.containsMouse ? Main.theme.colFg : Main.theme.colAccentDark
        font: Main.barFont

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detailsClicked()
        }
    }

    Switch {
        id: toggle
        visible: root.clickable
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 36
        implicitHeight: 20
        checked: root.active
        onToggled: root.clicked()
    }
}
