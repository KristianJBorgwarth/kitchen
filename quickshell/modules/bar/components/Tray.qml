import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.core
import qs.modules.widgets

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
            duration: Main.anim
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: TrayPanel.toggle()
    }

    Component.onCompleted: TrayPanel.anchorItem = root
}
