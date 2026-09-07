pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sway compositor memory usage
Singleton {
    id: root
    property real usedMiB: 0

    Process {
        id: swayMemProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/app_mem.sh sway"]
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
        onTriggered: swayMemProc.running = true
    }
}
