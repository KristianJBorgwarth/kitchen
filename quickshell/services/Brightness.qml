pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brightness — first /sys/class/backlight device, set through brightnessctl (goes via
// logind, so no udev rules needed). Reads are plain file reads, so polling costs no
// processes; one `ls` at startup finds the device. Unavailable on desktops.
Singleton {
    id: root
    property string device: ""
    property bool hasCtl: false
    readonly property bool available: device !== "" && hasCtl && max > 0
    property real max: 0
    property real value: 0

    Process {
        running: true
        command: ["sh", "-c", "command -v brightnessctl >/dev/null && echo ctl; ls -d /sys/class/backlight/* 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("\n");
                root.hasCtl = p[0] === "ctl";
                root.device = root.hasCtl ? (p[1] ?? "") : "";
            }
        }
    }

    FileView {
        id: maxFile
        path: root.device ? root.device + "/max_brightness" : ""
        blockLoading: true
        onLoaded: root.max = parseInt(text()) || 0
    }
    FileView {
        id: curFile
        path: root.device ? root.device + "/brightness" : ""
        blockLoading: true
        onLoaded: {
            if (root.max > 0)
                root.value = (parseInt(text()) || 0) / root.max;
        }
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

    // picks up changes from media keys / swayosd; sysfs has no change notifications
    Timer {
        interval: 3000
        running: root.available
        repeat: true
        onTriggered: curFile.reload()
    }
}
