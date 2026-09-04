pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Network — aggregate rx/tx rate across all non-loopback interfaces
Singleton {
    id: root
    readonly property int pollIntervalMs: 1000

    property real rxBps: 0
    property real txBps: 0
    property real lastRx: -1
    property real lastTx: -1

    function formatRate(bps) {
        if (bps < 1024)
            return bps.toFixed(0) + " B/s";
        if (bps < 1048576)
            return (bps / 1024).toFixed(1) + " KB/s";
        return (bps / 1048576).toFixed(1) + " MB/s";
    }

    property string rxLabel: formatRate(rxBps)
    property string txLabel: formatRate(txBps)

    Process {
        id: netProc
        command: ["sh", "-c", "awk -F'[: ]+' 'NR>2 && $2 != \"lo\" {rx+=$3; tx+=$11} END{print rx, tx}' /proc/net/dev"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                var rx = parseFloat(p[0]);
                var tx = parseFloat(p[1]);
                if (root.lastRx >= 0) {
                    var dt = root.pollIntervalMs / 1000;
                    root.rxBps = Math.max(0, (rx - root.lastRx) / dt);
                    root.txBps = Math.max(0, (tx - root.lastTx) / dt);
                }
                root.lastRx = rx;
                root.lastTx = tx;
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }
}
