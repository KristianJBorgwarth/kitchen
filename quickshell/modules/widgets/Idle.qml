import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import qs.core
import qs.services

// Dim, lock and power the displays off on idle (sway's ext-idle-notify). Inhibitors count:
// Stay awake, and apps like fullscreen video that ask for the screen to stay on.
// Locking before a sleep started elsewhere (lid, systemctl) is swayidle's before-sleep hook
// in the sway config, since that needs a logind delay lock this can't take.
Scope {
    id: root
    // seconds
    property int dimAfter: 240
    property int lockAfter: 300
    property int offAfter: 600
    property int offAfterWhileLocked: 60

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
    IdleMonitor {
        id: off
        timeout: Lock.locked ? root.offAfterWhileLocked : root.offAfter
    }

    // any input clears isIdle, which powers them back on
    Connections {
        target: off
        function onIsIdleChanged() {
            I3.dispatch("output * power " + (off.isIdle ? "off" : "on"));
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
