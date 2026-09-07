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
    anchors.bottom: true
    exclusiveZone: 0

    implicitWidth: 540
    implicitHeight: 140

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
        interval: 220
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

        transformOrigin: Item.Bottom
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

        Row {
            anchors.centerIn: parent
            spacing: 20

            Gauge {
                value: Number(Cpu.cpuUsage)
                label: "CPU"
                sublabel: Cpu.tempC + "°C"
            }
            Gauge {
                value: Gpu.usedPercent
                label: "GPU"
                sublabel: Gpu.tempC + "°C"
            }
            Gauge {
                value: Mem.usedPercent
                label: "RAM"
                sublabel: Mem.tempC + "°C"
            }
            Gauge {
                value: Storage.usedPercent
                displayText: Storage.usedGiB.toFixed(0) + "/" + Storage.totalGiB.toFixed(0) + "G"
                label: "DISK"
                sublabel: Storage.tempC + "°C"
            }
            Gauge {
                value: QsMem.usedMiB
                max: 1024
                unit: " MB"
                label: "Quickshell"
            }
            Gauge {
                value: SwayMem.usedMiB
                max: 1024
                unit: " MB"
                label: "Sway"
            }
        }
    }
}
