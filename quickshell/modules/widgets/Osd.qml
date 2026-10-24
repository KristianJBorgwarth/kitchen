pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Volume / mic / brightness popup for the media keys: changes the
// value, then shows it briefly at the bottom of the focused monitor.
Scope {
    id: root
    property string kind: "volume" // "volume", "mic", "brightness"
    property bool shown: false

    readonly property var node: kind === "mic" ? Audio.source : Audio.sink
    readonly property bool muted: kind !== "brightness" && (node?.audio?.muted ?? false)
    readonly property real value: kind === "brightness" ? Brightness.value : (node?.audio?.volume ?? 0)
    readonly property string icon: kind === "brightness" ? "󰃠" : kind === "mic" ? (muted ? "󰍭" : "󰍬") : muted || value === 0 ? "󰝟" : value < 0.34 ? "󰕿" : value < 0.67 ? "󰖀" : "󰕾"

    function show(k) {
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    function volume(d) {
        Audio.setVolume(Audio.sink, (Audio.sink?.audio?.volume ?? 0) + d);
        if (Audio.sink?.audio?.muted)
            Audio.toggleMute(Audio.sink);
        show("volume");
    }
    function toggleMute() {
        Audio.toggleMute(Audio.sink);
        show("volume");
    }
    function toggleMicMute() {
        Audio.toggleMute(Audio.source);
        show("mic");
    }
    function brightness(d) {
        if (!Brightness.available)
            return;
        Brightness.set(Brightness.value + d);
        show("brightness");
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Compositor.focusedMonitor) ?? null
        visible: pill.opacity > 0
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 80
        exclusiveZone: 0
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        implicitWidth: 300
        implicitHeight: 48

        Rectangle {
            id: pill
            anchors.fill: parent
            radius: Main.radius
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1
            opacity: root.shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.shown ? Main.anim : 200
                }
            }

            Text {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: root.icon
                color: root.muted ? Main.theme.colAccentDark : Main.theme.colFg
                font: Main.iconFont
            }

            Rectangle {
                anchors.left: icon.right
                anchors.leftMargin: 12
                anchors.right: pct.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Main.theme.colMuted

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.value))
                    height: parent.height
                    radius: 3
                    color: root.muted ? Main.theme.colAccentDark : root.kind === "brightness" ? Main.theme.colAmber : root.kind === "mic" ? Main.theme.colTeal : Main.theme.colGreen

                    Behavior on width {
                        NumberAnimation {
                            duration: Main.anim
                        }
                    }
                }
            }

            Text {
                id: pct
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "muted" : Math.round(root.value * 100) + "%"
                color: root.muted ? Main.theme.colAccentDark : Main.theme.colFg
                font: Main.barFont
            }
        }
    }
}
