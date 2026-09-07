pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell memory usage
Singleton {
    id: root
    property real usedMiB: 0

    Process {
        id: qsMemProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/app_mem.sh quickshell"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                root.usedMiB = parseInt(p[0]);
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: qsMemProc.running = true
    }
}
