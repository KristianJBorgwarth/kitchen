pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Session — user/host/uptime and power actions
Singleton {
    id: root
    readonly property string user: Quickshell.env("USER")
    property string host: ""
    property string uptime: ""

    Process {
        id: infoProc
        command: ["sh", "-c", "cat /proc/sys/kernel/hostname; cut -d. -f1 /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("\n");
                root.host = p[0];
                const s = parseInt(p[1]);
                const d = Math.floor(s / 86400);
                const h = Math.floor(s % 86400 / 3600);
                const m = Math.floor(s % 3600 / 60);
                root.uptime = (d > 0 ? d + "d " : "") + h + "h " + m + "m";
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: infoProc.running = true
    }

    function lock(): void {
        Quickshell.execDetached(["swaylock"]);
    }
    function logout(): void {
        Quickshell.execDetached(["swaymsg", "exit"]);
    }
    function suspend(): void {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }
    function reboot(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function poweroff(): void {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
}
