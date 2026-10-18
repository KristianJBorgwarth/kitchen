pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Cava — audio spectrum (0..1 per bar) from cava's raw output.
// Only runs while something is playing; available is false when cava isn't installed.
Singleton {
    id: root
    readonly property int count: 14
    property bool available: false
    readonly property bool active: Media.player?.isPlaying ?? false
    property var bars: new Array(count).fill(0)

    Process {
        command: ["sh", "-c", "command -v cava"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        id: cavaProc
        running: root.available && root.active
        command: ["cava", "-p", Quickshell.shellPath("scripts/cava.conf")]
        stdout: SplitParser {
            onRead: data => {
                const p = data.split(";");
                const out = new Array(root.count);
                for (let i = 0; i < root.count; i++)
                    out[i] = (parseInt(p[i]) || 0) / 100;
                root.bars = out;
            }
        }
        onRunningChanged: if (!running) root.bars = new Array(root.count).fill(0)
    }
}
