pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Mem
Singleton {
    id: root
    property real usedPercent: 0
    property real usedGiB: 0
    property real totalGiB: 0
    property real tempC: 0

    Process {
        id: memProc
        command: ["sh", "-c", "awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                var totalKb = parseInt(p[0]);
                var availKb = parseInt(p[1]);
                var usedKb = totalKb - availKb;
                root.usedPercent = Math.round(100 * usedKb / totalKb);
                root.totalGiB = totalKb / 1048576;
                root.usedGiB = usedKb / 1048576;
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: memTempProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/hwmon_temp.sh spd5118"]
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
            memProc.running = true;
            memTempProc.running = true;
        }
    }
}
