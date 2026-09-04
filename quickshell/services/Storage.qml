pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Storage — root filesystem usage
Singleton {
    id: root
    property real usedPercent: 0
    property real usedGiB: 0
    property real totalGiB: 0

    Process {
        id: dfProc
        command: ["sh", "-c", "df -k --output=used,size / | tail -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                var usedKb = parseInt(p[0]);
                var totalKb = parseInt(p[1]);
                root.usedPercent = Math.round(100 * usedKb / totalKb);
                root.totalGiB = totalKb / 1048576;
                root.usedGiB = usedKb / 1048576;
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: dfProc.running = true
    }
}
