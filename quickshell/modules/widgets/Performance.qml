pragma Singleton

import QtQuick
import Quickshell
import qs.core
import qs.services

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    anchors.top: true
    anchors.right: true

    implicitWidth: 220
    implicitHeight: 120

    margins {
        top: 4
        left: 4
        bottom: 4
        right: 4
    }

    function show() {
        root.visible = true;
    }

    function hide() {
        root.visible = false;
    }

    function toggle() {
        root.visible = !root.visible;
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Main.theme.colBg
        border.color: Main.theme.colFg
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "CPU: " + Cpu.cpuUsage + "%"
                color: Main.theme.colFg
                font: Main.barFont
            }
        }
    }
}
