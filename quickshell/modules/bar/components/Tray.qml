import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.core

Row {
    id: root
    spacing: 8

    property bool showTray: false

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.showTray ? "" : "" 
        color: Main.theme.colFg
        font: Main.barFont

        MouseArea {
            anchors.fill: parent
            onClicked: root.showTray = !root.showTray
        }
    }

    Repeater {
        model: root.showTray ? SystemTray.items : []

        delegate: IconImage {
            id: icon
            required property var modelData
            implicitSize: 16
            source: modelData.icon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (icon.modelData.hasMenu) {
                        const pos = QsWindow.itemPosition(icon);
                        icon.modelData.display(QsWindow.window, pos.x, pos.y + icon.height);
                    } else if (mouse.button === Qt.LeftButton) {
                        icon.modelData.activate();
                    } else {
                        icon.modelData.secondaryActivate();
                    }
                }
            }
        }
    }
}
