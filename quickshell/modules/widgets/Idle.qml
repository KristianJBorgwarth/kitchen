import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Dim and lock on idle (sway's ext-idle-notify). Inhibitors count: Stay awake, and apps like
// fullscreen video that ask for the screen to stay on. The displays are never powered off:
// monitors waking up under the lock crash quickshell (upstream quickshell #1340, #503).
// Locking before a sleep started elsewhere (lid, systemctl) is swayidle's before-sleep hook
// in the sway config, since that needs a logind delay lock this can't take.
Scope {
    id: root
    // seconds
    property int dimAfter: 240
    property int lockAfter: 300

    IdleMonitor {
        id: dim
        timeout: root.dimAfter
    }
    IdleMonitor {
        timeout: root.lockAfter
        onIsIdleChanged: {
            if (isIdle && !Lock.locked)
                Lock.lock();
        }
    }

    // the dim: a fading black layer that lets input straight through
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: shade.opacity > 0
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-dim"

            Rectangle {
                id: shade
                anchors.fill: parent
                color: "black"
                opacity: dim.isIdle && !Lock.locked ? 0.6 : 0

                // fades in slowly as a warning; snaps back on input
                Behavior on opacity {
                    NumberAnimation {
                        duration: shade.opacity < 0.3 ? 2000 : Main.anim
                    }
                }
            }
        }
    }
}
