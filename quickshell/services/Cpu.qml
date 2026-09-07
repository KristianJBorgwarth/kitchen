pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Cpu
Singleton {
    id: root
    property string cpuUsage: "0"
    property real lastCpuIdle: 0
    property real lastCpuTotal: 0
    property real tempC: 0

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                var idle = parseInt(p[4]) + parseInt(p[5]);
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0);
                if (root.lastCpuTotal > 0) {
                    root.cpuUsage = Math.round(100 * (1 - (idle - root.lastCpuIdle) / (total - root.lastCpuTotal)));
                }
                root.lastCpuIdle = idle;
                root.lastCpuTotal = total;
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: cpuTempProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/hwmon_temp.sh k10temp Tctl"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                root.tempC = parseInt(data.trim());
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true;
            cpuTempProc.running = true;
        }
    }
}
