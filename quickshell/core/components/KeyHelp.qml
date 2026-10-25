import QtQuick
import qs.core

Rectangle {
    id: root
    required property var vimKeys
    readonly property bool compact: width < 520

    anchors.fill: parent
    radius: parent.radius ?? 0
    color: Qt.rgba(Main.theme.colBg.r, Main.theme.colBg.g, Main.theme.colBg.b, 0.94)
    visible: opacity > 0
    opacity: vimKeys.helpVisible ? 1 : 0
    z: 100

    Behavior on opacity {
        NumberAnimation {
            duration: Main.anim
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.vimKeys.helpVisible = false
    }

    Column {
        anchors.centerIn: parent
        spacing: 16

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Keys"
        }

        Grid {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            // two columns only when they fit inside the card with a margin
            property var rowWidths: []
            readonly property real splitWidth: Math.max(0, ...rowWidths.filter((w, i) => i % 2 === 0)) + Math.max(0, ...rowWidths.filter((w, i) => i % 2 === 1)) + columnSpacing
            columns: root.vimKeys.bindings.length > 8 && splitWidth <= root.width - 48 ? 2 : 1
            columnSpacing: root.compact ? 24 : 40
            rowSpacing: root.compact ? 6 : 8

            Repeater {
                model: root.vimKeys.bindings.filter(b => b.desc)
                Row {
                    required property var modelData
                    required property int index
                    spacing: root.compact ? 8 : 12
                    onImplicitWidthChanged: {
                        const w = grid.rowWidths.slice();
                        w[index] = implicitWidth;
                        grid.rowWidths = w;
                    }
                    Rectangle {
                        width: Math.max(root.compact ? 28 : 44, keyText.implicitWidth + 14)
                        height: 22
                        radius: 4
                        color: Main.theme.colSurface
                        border.color: Main.theme.colMuted
                        border.width: 1
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: parent.parent.modelData.keys
                            color: Main.theme.colFg
                            font: Main.smallFont
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.desc
                        color: Main.theme.colAccentLight
                        font: root.compact ? Main.smallFont : Main.barFont
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "? or esc to close"
            color: Main.theme.colAccentDark
            font: Main.smallFont
        }
    }
}
