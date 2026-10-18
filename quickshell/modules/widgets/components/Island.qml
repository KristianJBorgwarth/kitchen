import QtQuick
import qs.core

// Rounded card with a small caps title row; children go in the body below it.
Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property string detail: ""
    default property alias content: body.data

    radius: 10
    color: Main.theme.colSurface
    border.color: Qt.rgba(1, 1, 1, 0.05)
    border.width: 1

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        text: (root.icon ? root.icon + "  " : "") + root.title.toUpperCase()
        color: Main.theme.colAccentMid
        font.family: Main.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 1.5
    }

    Text {
        anchors.right: parent.right
        anchors.left: titleText.right
        anchors.leftMargin: 12
        anchors.baseline: titleText.baseline
        anchors.rightMargin: 16
        horizontalAlignment: Text.AlignRight
        text: root.detail
        color: Main.theme.colAccentDark
        font: Main.smallFont
        elide: Text.ElideLeft
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 40
    }
}
