pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dnd — mako "do-not-disturb" mode (defined in mako/config)
Singleton {
    id: root
    property bool enabled: false

    Process {
        id: getProc
        command: ["sh", "-c", "makoctl mode 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.enabled = this.text.split("\n").includes("do-not-disturb")
        }
        Component.onCompleted: running = true
    }

    Process {
        id: toggleProc
        command: ["makoctl", "mode", "-t", "do-not-disturb"]
        onExited: getProc.running = true
    }

    function toggle(): void {
        toggleProc.running = true;
    }
}
