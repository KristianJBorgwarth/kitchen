pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Gpu — AMD integrated GPU usage + temp
Singleton {
    id: root
    property real usedPercent: 0
    property real tempC: 0

    Process {
        id: gpuUsageProc
        command: ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                root.usedPercent = parseInt(data.trim());
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: gpuTempProc
        command: ["sh", "-c", "~/.config/quickshell/scripts/hwmon_temp.sh amdgpu edge"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                root.tempC = parseInt(data.trim());
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            gpuUsageProc.running = true;
            gpuTempProc.running = true;
        }
    }
}
