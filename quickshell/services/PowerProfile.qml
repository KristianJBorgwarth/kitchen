pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// PowerProfile — power-profiles-daemon (or tuned-ppd) via powerprofilesctl
Singleton {
    id: root
    property bool available: false
    property string current: ""
    readonly property var profiles: ["power-saver", "balanced", "performance"]

    Process {
        id: getProc
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.current = this.text.trim();
                root.available = root.current.length > 0;
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: setProc
        onExited: getProc.running = true
    }

    function set(profile: string): void {
        current = profile;
        setProc.command = ["powerprofilesctl", "set", profile];
        setProc.running = true;
    }

    Timer {
        interval: 10000
        running: root.available
        repeat: true
        onTriggered: getProc.running = true
    }
}
