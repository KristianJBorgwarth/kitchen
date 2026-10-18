pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string user: Quickshell.env("USER")
    readonly property string host: hostFile.text().trim()
    property string uptime: ""

    FileView {
        id: hostFile
        path: "/proc/sys/kernel/hostname"
        blockLoading: true
    }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        onLoaded: {
            const s = parseInt(text());
            const d = Math.floor(s / 86400);
            const h = Math.floor(s % 86400 / 3600);
            const m = Math.floor(s % 3600 / 60);
            root.uptime = (d > 0 ? d + "d " : "") + h + "h " + m + "m";
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: uptimeFile.reload()
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
