import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.core
import qs.modules.widgets

// Tray button: opens the TrayPanel drawer under itself. Hidden with no tray items.
Text {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    visible: SystemTray.items.values.length > 0
    text: "\u{f003b}"
    color: TrayPanel.opened ? Main.theme.colAccentLight : Main.theme.colFg
    font: Main.barFont
    scale: TrayPanel.opened ? 0.85 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutBack
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: TrayPanel.toggle()
    }

    // the drawer drops down centered under this button
    Component.onCompleted: TrayPanel.anchorItem = root
}
