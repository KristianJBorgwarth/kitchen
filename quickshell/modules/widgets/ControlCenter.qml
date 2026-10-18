pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.core.components
import qs.services
import "components"

Scope {
    id: root
    property bool opened: false

    function show() {
        if (MusicPlayer.opened)
            MusicPlayer.hide();
        if (TrayPanel.opened)
            TrayPanel.hide();
        unmapTimer.stop();
        panel.visible = true;
        opened = true;
    }

    function hide() {
        opened = false;
        unmapTimer.restart();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    Timer {
        id: unmapTimer
        interval: 220
        onTriggered: {
            if (!root.opened)
                panel.visible = false;
        }
    }

    // invisible full-screen catcher so a click anywhere else closes the panel
    PanelWindow {
        visible: root.opened
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-controlcenter-backdrop"

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    PanelWindow {
        id: panel
        visible: false
        color: "transparent"
        anchors.top: true
        anchors.right: true
        exclusiveZone: 0
        margins.top: 4
        margins.right: 6
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-controlcenter"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        implicitWidth: 360
        implicitHeight: content.implicitHeight + 28

        Rectangle {
            id: blob
            anchors.fill: parent
            radius: 4
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1
            focus: true
            Keys.onPressed: event => vimKeys.handle(event)

            VimKeys {
                id: vimKeys
                function profileBy(d) {
                    if (!PowerProfile.available)
                        return;
                    const p = PowerProfile.profiles;
                    PowerProfile.set(p[Math.max(0, Math.min(p.length - 1, p.indexOf(PowerProfile.current) + d))]);
                }
                bindings: [
                    { keys: "k", desc: "volume up", run: () => Audio.setVolume(Audio.sink, (Audio.sink?.audio?.volume ?? 0) + 0.05) },
                    { keys: "j", desc: "volume down", run: () => Audio.setVolume(Audio.sink, (Audio.sink?.audio?.volume ?? 0) - 0.05) },
                    { keys: "m", desc: "mute", run: () => Audio.toggleMute(Audio.sink) },
                    { keys: "K", desc: "mic up", run: () => Audio.setVolume(Audio.source, (Audio.source?.audio?.volume ?? 0) + 0.05) },
                    { keys: "J", desc: "mic down", run: () => Audio.setVolume(Audio.source, (Audio.source?.audio?.volume ?? 0) - 0.05) },
                    { keys: "M", desc: "mute mic", run: () => Audio.toggleMute(Audio.source) },
                    { keys: "w", desc: "wi-fi", run: () => { if (Network.hasWifi) Network.toggleWifi(); } },
                    { keys: "b", desc: "bluetooth", run: () => Bt.toggle() },
                    { keys: "s", desc: "silent", run: () => Dnd.toggle() },
                    { keys: "c", desc: "caffeine", run: () => Caffeine.enabled = !Caffeine.enabled },
                    { keys: "h", desc: "power: save more", run: () => profileBy(-1) },
                    { keys: "l", desc: "power: perform more", run: () => profileBy(1) },
                    { keys: "L", desc: "lock", run: () => { root.hide(); Session.lock(); } },
                    { keys: "q", desc: "close", run: () => root.hide() },
                    { keys: "<Esc>", desc: "", run: () => root.hide() }
                ]
            }

            transformOrigin: Item.TopRight
            scale: root.opened ? 1 : 0
            opacity: root.opened ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Column {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // header: who/where + power actions
                Item {
                    width: parent.width
                    height: 36

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: Session.user + "@" + Session.host
                            color: Main.theme.colFg
                            font: Main.barFont
                        }
                        Text {
                            text: "up " + Session.uptime
                            color: Main.theme.colAccentMid
                            font: Main.smallFont
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        IconButton {
                            icon: "󰌾"
                            onClicked: {
                                root.hide();
                                Session.lock();
                            }
                        }
                        IconButton {
                            icon: "󰤄"
                            onClicked: {
                                root.hide();
                                Session.suspend();
                            }
                        }
                        IconButton {
                            icon: "󰍃"
                            confirm: true
                            onClicked: Session.logout()
                        }
                        IconButton {
                            icon: "󰜉"
                            confirm: true
                            onClicked: Session.reboot()
                        }
                        IconButton {
                            icon: "󰐥"
                            confirm: true
                            onClicked: Session.poweroff()
                        }
                    }
                }

                // quick toggles
                Grid {
                    id: tiles
                    width: parent.width
                    columns: 2
                    spacing: 8
                    readonly property real tileWidth: (width - spacing) / 2

                    ToggleTile {
                        width: tiles.tileWidth
                        icon: Network.hasWifi ? (Network.wifiEnabled ? "󰤨" : "󰤭") : "󰈀"
                        label: Network.hasWifi ? "Wi-Fi" : "Network"
                        sublabel: Network.hasWifi && !Network.wifiEnabled ? (Network.wired ? "Off · wired" : "Off") : Network.label
                        active: Network.hasWifi ? Network.wifiEnabled : Network.connected
                        clickable: Network.hasWifi
                        onClicked: Network.toggleWifi()
                    }
                    ToggleTile {
                        width: tiles.tileWidth
                        visible: Bt.available
                        icon: Bt.enabled ? "󰂯" : "󰂲"
                        label: "Bluetooth"
                        sublabel: Bt.label
                        active: Bt.enabled
                        onClicked: Bt.toggle()
                    }
                    ToggleTile {
                        width: tiles.tileWidth
                        icon: Dnd.enabled ? "󰂛" : "󰂚"
                        label: "Silent"
                        sublabel: Dnd.enabled ? "Notifications hidden" : "Off"
                        active: Dnd.enabled
                        onClicked: Dnd.toggle()
                    }
                    ToggleTile {
                        width: tiles.tileWidth
                        icon: "󰅶"
                        label: "Caffeine"
                        sublabel: Caffeine.enabled ? "Staying awake" : "Off"
                        active: Caffeine.enabled
                        onClicked: Caffeine.enabled = !Caffeine.enabled
                    }
                }

                // power profile (power-profiles-daemon only)
                Rectangle {
                    visible: PowerProfile.available
                    width: parent.width
                    height: 36
                    radius: 4
                    color: Main.theme.colSurface

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3
                        Repeater {
                            model: [
                                { id: "power-saver", icon: "󰾆", label: "Saver" },
                                { id: "balanced", icon: "󰾅", label: "Balanced" },
                                { id: "performance", icon: "󰓅", label: "Perf" }
                            ]
                            delegate: Rectangle {
                                id: seg
                                required property var modelData
                                readonly property bool selected: PowerProfile.current === modelData.id
                                width: parent.width / 3
                                height: parent.height
                                radius: 3
                                color: selected ? Main.theme.colFg : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: seg.modelData.icon + "  " + seg.modelData.label
                                    color: seg.selected ? Main.theme.colBg : Main.theme.colFg
                                    font: Main.barFont
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PowerProfile.set(seg.modelData.id)
                                }
                            }
                        }
                    }
                }

                // sliders
                Column {
                    width: parent.width
                    spacing: 4

                    SliderRow {
                        width: parent.width
                        visible: Audio.sink !== null
                        readonly property bool muted: Audio.sink?.audio?.muted ?? false
                        icon: muted ? "󰝟" : "󰕾"
                        dimmed: muted
                        value: Audio.sink?.audio?.volume ?? 0
                        onMoved: v => Audio.setVolume(Audio.sink, v)
                        onIconClicked: Audio.toggleMute(Audio.sink)
                    }
                    SliderRow {
                        width: parent.width
                        visible: Audio.source !== null
                        readonly property bool muted: Audio.source?.audio?.muted ?? false
                        icon: muted ? "󰍭" : "󰍬"
                        dimmed: muted
                        value: Audio.source?.audio?.volume ?? 0
                        onMoved: v => Audio.setVolume(Audio.source, v)
                        onIconClicked: Audio.toggleMute(Audio.source)
                    }
                    SliderRow {
                        width: parent.width
                        visible: Brightness.available
                        icon: "󰃠"
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }
                }

                MediaCard {
                    width: parent.width
                    visible: Media.player !== null
                    player: Media.player

                    // the card's own buttons sit above this, so it only catches clicks elsewhere
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicPlayer.show()
                    }
                }
            }

            KeyHelp {
                vimKeys: vimKeys
            }
        }
    }
}
