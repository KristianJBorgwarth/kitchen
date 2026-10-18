pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light via gammastep, which has to keep running: wlroots drops a gamma adjustment
// as soon as its process exits. On/off and warmth are remembered.
Singleton {
    id: root
    property bool available: false
    readonly property bool enabled: settings.enabled
    readonly property int temperature: settings.temperature

    function toggle(): void {
        settings.enabled = !settings.enabled;
    }

    function setTemperature(k: int): void {
        settings.temperature = Math.round(Math.max(2500, Math.min(6000, k)) / 100) * 100;
    }

    FileView {
        printErrors: false
        path: Quickshell.statePath("nightlight.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property bool enabled: false
            property int temperature: 4000
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v gammastep"]
        onExited: code => root.available = code === 0
    }

    property bool restarting: false

    Process {
        id: gammastep
        // pkill first: a config reload leaves the old gammastep running with nobody to stop it
        command: ["sh", "-c", "pkill -x gammastep; exec gammastep -m wayland -O " + root.temperature]
        // only restart when we stopped it ourselves, so a failing gammastep can't loop
        onExited: {
            if (root.restarting) {
                root.restarting = false;
                if (!root.enabled)
                    sweep.running = true;
                root.start();
            }
        }
    }

    function start() {
        if (enabled && available)
            gammastep.running = true;
    }

    Process {
        id: sweep
        command: ["pkill", "-x", "gammastep"]
    }

    Component.onDestruction: gammastep.running = false

    // apply changes after a short pause, so dragging the slider doesn't respawn per pixel
    Timer {
        id: apply
        interval: 300
        onTriggered: {
            if (gammastep.running) {
                root.restarting = true;
                gammastep.running = false;
            } else {
                if (!root.enabled)
                    sweep.running = true;
                root.start();
            }
        }
    }
    onEnabledChanged: apply.restart()
    onTemperatureChanged: apply.restart()
    onAvailableChanged: apply.restart()
}
