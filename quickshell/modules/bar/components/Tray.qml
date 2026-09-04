import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: root
    spacing: 8

    Repeater {
        model: SystemTray.items

        IconImage {
            id: icon
            required property var modelData
            implicitSize: 16
            source: modelData.icon

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (modelData.hasMenu) {
                        const pos = QsWindow.itemPosition(icon);
                        modelData.display(QsWindow.window, pos.x, pos.y + icon.height);
                    } else if (mouse.button === Qt.LeftButton) {
                        modelData.activate();
                    } else {
                        modelData.secondaryActivate();
                    }
                }
            }
        }
    }
}
