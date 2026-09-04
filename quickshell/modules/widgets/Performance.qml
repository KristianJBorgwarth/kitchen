pragma Singleton

import QtQuick
import Quickshell
import qs.core
import qs.services
import "components"

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    anchors.top: true
    anchors.right: true

    implicitWidth: 320
    implicitHeight: 110

    margins {
        top: 4
        left: 4
        bottom: 4
        right: 4
    }

    property bool opened: false

    function show() {
        unmapTimer.stop();
        root.visible = true;
        opened = true;
    }

    function hide() {
        opened = false;
        unmapTimer.restart();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    Timer {
        id: unmapTimer
        interval: 220 // matches the scale Behavior duration below
        onTriggered: {
            if (!root.opened)
                root.visible = false;
        }
    }

    Rectangle {
        id: blob
        anchors.fill: parent
        radius: 4
        color: Main.theme.colBg
        border.color: Main.theme.colMuted
        border.width: 1

        transformOrigin: Item.TopRight
        scale: root.opened ? 1 : 0
        opacity: root.opened ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Row {
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter

                Gauge {
                    value: Number(Cpu.cpuUsage)
                    label: "CPU"
                }
                Gauge {
                    value: Mem.usedPercent
                    label: "RAM"
                }
                Gauge {
                    value: Storage.usedPercent
                    label: "DISK"
                }
            }
        }
    }
}
