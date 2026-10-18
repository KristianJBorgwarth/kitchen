import QtQuick
import qs.core
import qs.core.components

Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property string detail: ""
    default property alias content: body.data

    radius: Main.radius
    color: Main.theme.colSurface
    border.color: Main.theme.overlay(0.05)
    border.width: 1

    SectionLabel {
        id: titleText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        text: (root.icon ? root.icon + "  " : "") + root.title
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
