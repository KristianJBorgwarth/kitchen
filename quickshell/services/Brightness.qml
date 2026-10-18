pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brightness — first /sys/class/backlight device, set through brightnessctl
// (goes via logind, so no udev rules needed). Unavailable on desktops.
Singleton {
    id: root
    property bool available: false
    property real value: 0

    Process {
        id: readProc
        command: ["sh", "-c", "command -v brightnessctl >/dev/null || exit 0; d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1); [ -n \"$d\" ] && echo $(cat $d/brightness) $(cat $d/max_brightness)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(/\s+/);
                root.available = p.length === 2;
                if (root.available)
                    root.value = parseInt(p[0]) / parseInt(p[1]);
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: setProc
    }

    function set(v: real): void {
        if (!available)
            return;
        value = Math.max(0.01, Math.min(1, v));
        setProc.command = ["brightnessctl", "-q", "set", Math.round(value * 100) + "%"];
        setProc.running = true;
    }

    // picks up changes from media keys / swayosd
    Timer {
        interval: 3000
        running: root.available
        repeat: true
        onTriggered: readProc.running = true
    }
}
