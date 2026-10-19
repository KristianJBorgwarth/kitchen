import QtQuick
import qs.core
import qs.core.components

// The screenshot action bar: how to select and f for the whole monitor until there's a
// selection, then the drawing tools, inks and undo. `shot` is the Screenshot singleton.
Rectangle {
    id: root
    required property var shot
    signal screenRequested

    width: actions.implicitWidth + 16
    height: actions.implicitHeight + 16
    radius: Main.radius
    color: Main.theme.colBg
    border.color: Main.theme.colMuted
    border.width: 1

    Row {
        id: actions
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            rightPadding: 6
            text: "󰹑"
            color: Main.theme.colFg
            font: Main.iconFont
        }
        Text {
            visible: !root.shot.hasSel
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 6
            text: "click a window · drag a region"
            color: Main.theme.colAccentMid
            font: Main.smallFont
        }
        Chip {
            visible: !root.shot.hasSel
            text: "<b>f</b>  screen"
            clickable: true
            onClicked: root.screenRequested()
        }

        Repeater {
            model: root.shot.hasSel ? root.shot.tools : []
            Chip {
                required property var modelData
                text: "<b>" + modelData.key + "</b>  " + modelData.label
                active: root.shot.tool === modelData.id
                tint: root.shot.ink
                clickable: true
                onClicked: root.shot.setTool(modelData.id)
            }
        }
        Row {
            visible: root.shot.hasSel
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 4
            rightPadding: 4
            spacing: 6

            Repeater {
                model: root.shot.inks
                Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: modelData.color
                    border.color: Main.theme.colFg
                    border.width: Qt.colorEqual(root.shot.ink, modelData.color) ? 2 : 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shot.ink = parent.modelData.color
                    }
                }
            }
        }
        Chip {
            visible: root.shot.hasSel
            text: "<b>u</b>  undo"
            clickable: root.shot.marks.length > 0
            opacity: root.shot.marks.length > 0 ? 1 : 0.4
            onClicked: root.shot.undo()
        }
        Chip {
            text: "<b>⏎</b>  copy"
            active: root.shot.hasSel
            filled: true
            tint: Main.theme.colBlue
            clickable: root.shot.hasSel
            opacity: root.shot.hasSel ? 1 : 0.4
            onClicked: root.shot.finish("copy")
        }
        Chip {
            text: "<b>Esc</b>"
            clickable: true
            onClicked: root.shot.close()
        }
    }
}
