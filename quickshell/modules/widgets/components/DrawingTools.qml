import QtQuick
import qs.core
import qs.core.components

// Chips for the drawing tools, inks and undo of `owner`, the Draw or Screenshot singleton.
Row {
    id: root
    required property var owner
    spacing: 6

    Repeater {
        model: root.owner.tools
        Chip {
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            text: "<b>" + modelData.key + "</b>  " + modelData.label
            active: root.owner.tool === modelData.id
            tint: root.owner.ink
            clickable: true
            onClicked: root.owner.setTool(modelData.id)
        }
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 4
        rightPadding: 4
        spacing: 6

        Repeater {
            model: root.owner.inks
            Rectangle {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: modelData.color
                border.color: Main.theme.colFg
                border.width: Qt.colorEqual(root.owner.ink, modelData.color) ? 2 : 0

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.owner.ink = parent.modelData.color
                }
            }
        }
    }
    Chip {
        anchors.verticalCenter: parent.verticalCenter
        text: "<b>u</b>  undo"
        clickable: root.owner.history.length > 0
        opacity: root.owner.history.length > 0 ? 1 : 0.4
        onClicked: root.owner.undo()
    }
}
