pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking as QsNet
import Quickshell.Services.UPower as QsPower
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

Scope {
    id: root
    readonly property alias opened: modal.opened
    property string tab: "sound" // "sound", "network", "bluetooth", "notifications"
    readonly property var tabs: ["sound", "network", "bluetooth", "notifications"]
    // ticks the "2m ago" labels in the notifications tab
    property real now: Date.now()

    property string pskFor: ""
    property string pskText: ""
    onPskForChanged: pskText = ""

    readonly property var battery: QsPower.UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryLevel: {
        const p = battery?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }

    function show() {
        pskFor = "";
        modal.show();
    }

    function hide() {
        modal.hide();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    function openTab(t) {
        tab = t;
        pskFor = "";
    }

    function cycleTab(d) {
        openTab(tabs[(tabs.indexOf(tab) + d + tabs.length) % tabs.length]);
    }

    function profileBy(d) {
        if (!PowerProfile.available)
            return;
        const p = PowerProfile.profiles;
        PowerProfile.set(p[Math.max(0, Math.min(p.length - 1, p.indexOf(PowerProfile.current) + d))]);
    }

    function signalIcon(s) {
        return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : s > 0.05 ? "󰤟" : "󰤯";
    }

    // live device lists only while visible
    Binding {
        target: Audio
        property: "detailed"
        value: root.opened
    }
    Binding {
        target: Monitor
        property: "wantSensors"
        value: root.opened
    }
    Binding {
        target: Network
        property: "scanning"
        value: root.opened && root.tab === "network"
    }

    Modal {
        id: modal
        title: "Control center"
        glyph: "󰒓"
        maxWidth: 1120
        // as tall as the left column needs, plus the frame's header and footer
        maxHeight: Math.max(620, leftCol.implicitHeight + padding * 2 + 64)
        padding: Main.pad
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
            { keys: "n", desc: "night light", run: () => NightLight.toggle() },
            { keys: "d", desc: "dark / light mode", run: () => Main.theme.toggle() },
            { keys: "a", desc: "stay awake", run: () => Awake.enabled = !Awake.enabled },
            { keys: "h", desc: "power: save more", run: () => root.profileBy(-1) },
            { keys: "l", desc: "power: perform more", run: () => root.profileBy(1) },
            { keys: "1", desc: "sound tab", run: () => root.openTab("sound") },
            { keys: "2", desc: "network tab", run: () => root.openTab("network") },
            { keys: "3", desc: "bluetooth tab", run: () => root.openTab("bluetooth") },
            { keys: "4", desc: "notifications tab", run: () => root.openTab("notifications") },
            { keys: "X", desc: "clear notifications", run: () => Notifs.clearAll() },
            { keys: "gt", desc: "next tab", run: () => root.cycleTab(1) },
            { keys: "gT", desc: "previous tab", run: () => root.cycleTab(-1) },
            { keys: "L", desc: "lock", run: () => { root.hide(); Lock.lock(); } },
            { keys: "<Esc>", desc: "", run: () => root.pskFor ? root.pskFor = "" : root.hide() }
        ]

        Item {
            id: layout
            anchors.fill: parent

            Column {
                id: leftCol
                width: Math.max(320, Math.min(420, layout.width * 0.38))
                height: parent.height
                spacing: 14

                Item {
                    width: parent.width
                    height: 96

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 4

                        Text {
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: Main.theme.colFg
                            font: Main.displayFont
                        }
                        Text {
                            text: clock.date.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                            color: Main.theme.colAccentLight
                            font: Main.barFont
                        }
                        Text {
                            width: parent.width
                            text: Session.user + "@" + Session.host + "  ·  up " + Session.uptime
                            color: Main.theme.colAccentMid
                            font: Main.smallFont
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        visible: root.hasBattery
                        height: 24
                        width: battText.implicitWidth + 20
                        radius: Main.radius
                        readonly property color tint: root.batteryLevel < 0.15 ? Main.theme.colRed : root.batteryLevel < 0.35 ? Main.theme.colAmber : Main.theme.colAccentLight
                        color: Qt.rgba(tint.r, tint.g, tint.b, 0.15)
                        Text {
                            id: battText
                            anchors.centerIn: parent
                            readonly property bool charging: root.battery?.state === QsPower.UPowerDeviceState.Charging || root.battery?.state === QsPower.UPowerDeviceState.FullyCharged
                            text: (charging ? "󰂄 " : "󰁹 ") + Math.round(root.batteryLevel * 100) + "%"
                            color: parent.tint
                            font: Main.smallFont
                        }
                    }
                }

                Row {
                    spacing: 4
                    Repeater {
                        model: [
                            { icon: "󰌾", tip: "Lock", confirm: false, run: () => { root.hide(); Lock.lock(); } },
                            { icon: "󰤄", tip: "Sleep", confirm: false, run: () => { root.hide(); Lock.suspend(); } },
                            { icon: "󰍃", tip: "Log out", confirm: true, run: () => Session.logout() },
                            { icon: "󰜉", tip: "Reboot", confirm: true, run: () => Session.reboot() },
                            { icon: "󰐥", tip: "Power off", confirm: true, run: () => Session.poweroff() }
                        ]
                        IconButton {
                            required property var modelData
                            implicitWidth: 34
                            implicitHeight: 34
                            icon: modelData.icon
                            iconFont: Main.pillFont
                            confirm: modelData.confirm
                            armedColor: Main.theme.colRed
                            tooltip: modelData.tip
                            armedTooltip: "Click again to " + modelData.tip.toLowerCase()
                            onClicked: modelData.run()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: toggles.implicitHeight + 8
                    radius: Main.radius
                    color: Main.theme.overlay(0.03)

                    Column {
                        id: toggles
                        anchors.fill: parent
                        anchors.margins: 4

                        ToggleRow {
                            width: parent.width
                            icon: Network.hasWifi ? (Network.wifiEnabled ? "󰤨" : "󰤭") : "󰈀"
                            label: Network.hasWifi ? "Wi-Fi" : "Network"
                            sublabel: Network.hasWifi && !Network.wifiEnabled ? (Network.wired ? "wired" : "") : Network.label
                            active: Network.hasWifi ? Network.wifiEnabled : Network.connected
                            clickable: Network.hasWifi
                            hasDetails: true
                            onClicked: Network.toggleWifi()
                            onDetailsClicked: root.openTab("network")
                        }
                        ToggleRow {
                            width: parent.width
                            visible: Bt.available
                            icon: Bt.enabled ? "󰂯" : "󰂲"
                            label: "Bluetooth"
                            sublabel: Bt.enabled ? Bt.label : ""
                            active: Bt.enabled
                            hasDetails: true
                            onClicked: Bt.toggle()
                            onDetailsClicked: root.openTab("bluetooth")
                        }
                        ToggleRow {
                            width: parent.width
                            readonly property bool muted: Audio.source?.audio?.muted ?? false
                            icon: muted ? "󰍭" : "󰍬"
                            label: "Microphone"
                            sublabel: muted ? "muted" : ""
                            active: !muted
                            onClicked: Audio.toggleMute(Audio.source)
                        }
                        ToggleRow {
                            width: parent.width
                            icon: Dnd.enabled ? "󰂛" : "󰂚"
                            label: "Silent"
                            active: Dnd.enabled
                            onClicked: Dnd.toggle()
                        }
                        ToggleRow {
                            width: parent.width
                            visible: NightLight.available
                            icon: "󰖔"
                            label: "Night light"
                            sublabel: NightLight.enabled ? NightLight.temperature + "K" : ""
                            active: NightLight.enabled
                            onClicked: NightLight.toggle()
                        }
                        ToggleRow {
                            width: parent.width
                            icon: Main.theme.dark ? "󰖔" : "󰖙"
                            label: "Dark mode"
                            active: Main.theme.dark
                            onClicked: Main.theme.toggle()
                        }
                        ToggleRow {
                            width: parent.width
                            icon: "󰈈"
                            label: "Stay awake"
                            active: Awake.enabled
                            onClicked: Awake.enabled = !Awake.enabled
                        }
                    }
                }

                // night light warmth, while it's on
                Rectangle {
                    visible: NightLight.available && NightLight.enabled
                    width: parent.width
                    height: 36
                    color: "transparent"
                    SliderRow {
                        anchors.fill: parent
                        icon: "󰖔"
                        accent: Main.theme.colFg
                        // warmer to the right: 6000K → 2500K
                        value: (6000 - NightLight.temperature) / 3500
                        onMoved: v => NightLight.setTemperature(6000 - v * 3500)
                    }
                }

                Rectangle {
                    visible: PowerProfile.available
                    width: parent.width
                    height: 34
                    radius: Main.radius
                    color: Main.theme.overlay(0.03)

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: [
                                { id: "power-saver", icon: "󰾆", label: "Saver" },
                                { id: "balanced", icon: "󰾅", label: "Balanced" },
                                { id: "performance", icon: "󰓅", label: "Performance" }
                            ]
                            delegate: Rectangle {
                                id: seg
                                required property var modelData
                                readonly property bool selected: PowerProfile.current === modelData.id
                                width: parent.width / 3
                                height: parent.height
                                radius: Main.radius
                                color: selected ? Main.theme.overlay(0.1) : (segMouse.containsMouse ? Main.theme.overlay(0.05) : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Main.anim
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: seg.modelData.icon + "  " + seg.modelData.label
                                    color: seg.selected ? Main.theme.colFg : Main.theme.colAccentMid
                                    font: Main.smallFont
                                }
                                MouseArea {
                                    id: segMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PowerProfile.set(seg.modelData.id)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: Brightness.available
                    width: parent.width
                    height: 36
                    color: "transparent"
                    SliderRow {
                        anchors.fill: parent
                        icon: "󰃠"
                        accent: Main.theme.colFg
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }
                }

                // live system stats; the full monitor is a click away
                Rectangle {
                    width: parent.width
                    height: stats.implicitHeight + 28
                    radius: Main.radius
                    color: statsMouse.containsMouse ? Main.theme.overlay(0.04) : "transparent"

                    MouseArea {
                        id: statsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemMonitor.show()
                    }

                    Column {
                        id: stats
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 10

                        Item {
                            width: parent.width
                            height: statsTitle.implicitHeight
                            SectionLabel {
                                id: statsTitle
                                text: "System"
                            }
                            Text {
                                anchors.right: parent.right
                                text: "open monitor 󰁔"
                                color: statsMouse.containsMouse ? Main.theme.colFg : Main.theme.colAccentDark
                                font: Main.smallFont
                            }
                        }

                        Grid {
                            id: statGrid
                            width: parent.width
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 10

                            Repeater {
                                model: [
                                    { label: "CPU", value: Monitor.cpuUsage, text: Math.round(Monitor.cpuUsage) + "%", tint: Main.theme.colAccentLight },
                                    { label: "Memory", value: Monitor.memUsage, text: Monitor.memUsed.toFixed(1) + " / " + Math.round(Monitor.memTotal) + "G", tint: Main.theme.colAccentLight },
                                    { label: "GPU", value: Monitor.gpuUsage, text: Monitor.gpuVendor ? Math.round(Monitor.gpuUsage) + "%" : "n/a", tint: Main.theme.colAccentLight },
                                    { label: "CPU temp", value: Monitor.cpuTemp, text: Monitor.cpuTemp > 0 ? Monitor.cpuTemp + "°C" : "…", tint: Monitor.cpuTemp >= 85 ? Main.theme.colRed : Main.theme.colAccentLight }
                                ]
                                Column {
                                    required property var modelData
                                    width: (statGrid.width - statGrid.columnSpacing) / 2
                                    spacing: 5
                                    Item {
                                        width: parent.width
                                        height: statLabel.implicitHeight
                                        Text {
                                            id: statLabel
                                            text: parent.parent.modelData.label
                                            color: Main.theme.colAccentLight
                                            font: Main.smallFont
                                        }
                                        Text {
                                            anchors.right: parent.right
                                            text: parent.parent.modelData.text
                                            color: Main.theme.colFg
                                            font: Main.smallFont
                                        }
                                    }
                                    Meter {
                                        width: parent.width
                                        height: 4
                                        max: 100
                                        segments: [{ value: parent.modelData.value, color: parent.modelData.tint }]
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: rightCol
                anchors.left: leftCol.right
                anchors.leftMargin: 20
                anchors.right: parent.right
                height: parent.height

                Item {
                    id: tabBar
                    width: parent.width
                    height: 40

                    Rectangle {
                        id: tabTrack
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: tabRow.implicitWidth + 8
                        height: 36
                        radius: Main.radius
                        color: "transparent"

                        readonly property var defs: [
                            { id: "sound", icon: "󰕾", label: "Sound" },
                            { id: "network", icon: "󰛳", label: "Network" },
                            { id: "bluetooth", icon: "󰂯", label: "Bluetooth" },
                            { id: "notifications", icon: "󰂚", label: "Notifications" }
                        ]
                        readonly property int index: root.tabs.indexOf(root.tab)

                        // follows the active tab's own position and width. itemAt() isn't a
                        // binding source, so count makes it re-run once the buttons exist
                        Rectangle {
                            readonly property Item active: tabButtons.count > tabTrack.index ? tabButtons.itemAt(tabTrack.index) : null
                            x: 4 + (active?.x ?? 0)
                            y: 4
                            width: active?.width ?? 0
                            height: tabTrack.height - 8
                            radius: Main.radius
                            color: Main.theme.overlay(0.1)

                            Behavior on x {
                                NumberAnimation {
                                    duration: Main.anim
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: Main.anim
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Row {
                            id: tabRow
                            x: 4
                            y: 4
                            height: parent.height - 8
                            Repeater {
                                id: tabButtons
                                model: tabTrack.defs
                                Item {
                                    id: tabItem
                                    required property var modelData
                                    width: tabText.implicitWidth + 32
                                    height: parent.height
                                    Text {
                                        id: tabText
                                        anchors.centerIn: parent
                                        text: tabItem.modelData.icon + "  " + tabItem.modelData.label
                                        color: root.tab === tabItem.modelData.id ? Main.theme.colFg : Main.theme.colAccentMid
                                        font: Main.barFont
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openTab(tabItem.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: pane
                    anchors.top: tabBar.bottom
                    anchors.topMargin: 14
                    anchors.bottom: parent.bottom
                    width: parent.width
                    color: "transparent"
                    clip: true

                    Divider {
                        width: parent.width
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.topMargin: Main.gap
                        visible: root.tab === "sound"
                        contentHeight: sound.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: sound
                            width: parent.width
                            spacing: 10

                            // static outer model; the live node/device values are read inside,
                            // so device changes don't rebuild these sections
                            Repeater {
                                model: [
                                    { title: "Output", output: true, tint: Main.theme.colFg, on: "󰕾", off: "󰝟" },
                                    { title: "Input", output: false, tint: Main.theme.colFg, on: "󰍬", off: "󰍭" }
                                ]
                                Column {
                                    id: dev
                                    required property var modelData
                                    readonly property var node: modelData.output ? Audio.sink : Audio.source
                                    readonly property var devices: modelData.output ? Audio.sinks : Audio.sources
                                    width: sound.width
                                    spacing: 8
                                    bottomPadding: 10

                                    SectionLabel {
                                        text: dev.modelData.title
                                    }

                                    SliderRow {
                                        width: parent.width
                                        readonly property bool muted: dev.node?.audio?.muted ?? false
                                        icon: muted ? dev.modelData.off : dev.modelData.on
                                        dimmed: muted
                                        accent: dev.modelData.tint
                                        value: dev.node?.audio?.volume ?? 0
                                        onMoved: v => Audio.setVolume(dev.node, v)
                                        onIconClicked: Audio.toggleMute(dev.node)
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: 6
                                        visible: dev.devices.length > 1
                                        Repeater {
                                            model: ScriptModel {
                                                values: root.opened ? dev.devices : []
                                            }
                                            Chip {
                                                required property var modelData
                                                implicitHeight: 26
                                                maxWidth: sound.width
                                                text: Audio.label(modelData)
                                                tint: dev.modelData.tint
                                                active: modelData === dev.node
                                                clickable: true
                                                onClicked: Audio.setDefault(modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            SectionLabel {
                                text: "Applications"
                            }
                            Text {
                                visible: Audio.streams.length === 0
                                text: "Nothing is playing"
                                color: Main.theme.colAccentDark
                                font: Main.barFont
                            }

                            // ScriptModel diffs the list, so rows only come and go with their stream;
                            // like the other lists here it's empty while closed, so hidden rows don't churn
                            Repeater {
                                model: ScriptModel {
                                    values: root.opened ? Audio.streams : []
                                }
                                Item {
                                    id: app
                                    required property var modelData
                                    width: sound.width
                                    height: 40
                                    // streams can vanish mid-update, so every read here tolerates a missing node
                                    readonly property var props: modelData?.properties ?? {}
                                    readonly property string iconName: props["application.icon-name"] || DesktopEntries.heuristicLookup(props["application.process.binary"] || "")?.icon || ""

                                    IconImage {
                                        id: appIcon
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitSize: 22
                                        source: app.iconName ? Quickshell.iconPath(app.iconName, true) : ""
                                        visible: app.iconName !== ""
                                    }
                                    Text {
                                        anchors.centerIn: appIcon
                                        visible: app.iconName === ""
                                        text: "󰎈"
                                        color: Main.theme.colAccentMid
                                        font: Main.iconFont
                                    }
                                    Text {
                                        id: appName
                                        anchors.left: parent.left
                                        anchors.leftMargin: 34
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 120
                                        text: Audio.label(app.modelData) || ""
                                        color: Main.theme.colFg
                                        font: Main.barFont
                                        elide: Text.ElideRight
                                    }
                                    SliderRow {
                                        anchors.left: appName.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        readonly property bool muted: app.modelData?.audio?.muted ?? false
                                        icon: muted ? "󰝟" : "󰕾"
                                        dimmed: muted
                                        accent: Main.theme.colFg
                                        value: app.modelData?.audio?.volume ?? 0
                                        onMoved: v => Audio.setVolume(app.modelData, v)
                                        onIconClicked: Audio.toggleMute(app.modelData)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.topMargin: Main.gap
                        visible: root.tab === "network"

                        Column {
                            id: netHead
                            width: parent.width
                            spacing: 12

                            Row {
                                visible: Network.wiredDevice !== null
                                spacing: 10
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Network.wiredDevice?.connected ? Main.theme.colFg : Main.theme.colMuted
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰈀  Ethernet"
                                    color: Main.theme.colFg
                                    font: Main.barFont
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Network.wiredDevice?.connected ? "Connected" + ((Network.wiredDevice?.linkSpeed ?? 0) > 0 ? " · " + (Network.wiredDevice.linkSpeed >= 1000 ? Network.wiredDevice.linkSpeed / 1000 + " Gb/s" : Network.wiredDevice.linkSpeed + " Mb/s") : "") : "Unplugged"
                                    color: Main.theme.colAccentMid
                                    font: Main.smallFont
                                }
                            }

                            Item {
                                visible: Network.hasWifi
                                width: parent.width
                                height: 28
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰤨  Wi-Fi"
                                    color: Main.theme.colFg
                                    font: Main.barFont
                                }
                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: Network.wifiEnabled
                                        text: "scanning…"
                                        color: Main.theme.colAccentDark
                                        font: Main.smallFont
                                    }
                                    Switch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: Network.wifiEnabled
                                        onToggled: Network.toggleWifi()
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !Network.hasWifi || !Network.wifiEnabled
                            text: !Network.hasWifi ? "No Wi-Fi adapter" : "Wi-Fi is off"
                            color: Main.theme.colAccentDark
                            font: Main.barFont
                        }

                        ListView {
                            anchors.top: netHead.bottom
                            anchors.topMargin: 10
                            anchors.bottom: parent.bottom
                            width: parent.width
                            visible: Network.hasWifi && Network.wifiEnabled
                            clip: true
                            spacing: 4
                            model: ScriptModel {
                                values: root.opened && root.tab === "network" ? Network.wifiNetworks : []
                            }
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: net
                                required property var modelData
                                readonly property bool open: modelData.security === QsNet.WifiSecurityType.Open || modelData.security === QsNet.WifiSecurityType.Owe
                                readonly property bool expanded: root.pskFor === modelData.name
                                width: ListView.view.width
                                height: expanded ? 88 : 44
                                radius: Main.radius
                                color: modelData.connected ? Main.theme.overlay(0.06) : (netMouse.containsMouse ? Main.theme.overlay(0.05) : "transparent")
                                border.color: modelData.connected ? "transparent" : "transparent"
                                border.width: 1

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Main.anim
                                    }
                                }

                                MouseArea {
                                    id: netMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (net.modelData.connected)
                                            return;
                                        if (net.modelData.known || net.open)
                                            net.modelData.connect();
                                        else
                                            root.pskFor = net.expanded ? "" : net.modelData.name;
                                    }
                                }

                                Item {
                                    id: netRow
                                    width: parent.width
                                    height: 44

                                    Text {
                                        id: sig
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.signalIcon(net.modelData.signalStrength)
                                        color: net.modelData.connected ? Main.theme.colFg : Main.theme.colAccentLight
                                        font: Main.iconFont
                                    }
                                    Column {
                                        anchors.left: sig.right
                                        anchors.leftMargin: 12
                                        anchors.right: actions.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            width: parent.width
                                            text: net.modelData.name + (net.open ? "" : "  󰌾")
                                            color: Main.theme.colFg
                                            font: Main.barFont
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            visible: text !== ""
                                            text: net.modelData.stateChanging ? "Connecting…" : net.modelData.connected ? "Connected" : net.modelData.known ? "Saved" : ""
                                            color: net.modelData.connected ? Main.theme.colFg : Main.theme.colAccentMid
                                            font: Main.smallFont
                                        }
                                    }
                                    Row {
                                        id: actions
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        IconButton {
                                            visible: net.modelData.connected
                                            implicitWidth: 30
                                            implicitHeight: 30
                                            icon: "󰖪"
                                            iconFont: Main.barFont
                                            onClicked: net.modelData.disconnect()
                                        }
                                        IconButton {
                                            visible: net.modelData.known
                                            implicitWidth: 30
                                            implicitHeight: 30
                                            icon: "󰆴"
                                            iconFont: Main.barFont
                                            confirm: true
                                            onClicked: net.modelData.forget()
                                        }
                                    }
                                }

                                Row {
                                    visible: net.expanded
                                    anchors.top: netRow.bottom
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    spacing: 8

                                    Rectangle {
                                        width: net.width - 120
                                        height: 32
                                        radius: Main.radius
                                        color: Main.theme.colBg
                                        border.color: psk.activeFocus ? Main.theme.colFg : Main.theme.colMuted
                                        border.width: 1
                                        TextInput {
                                            id: psk
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: TextInput.Password
                                            color: Main.theme.colFg
                                            font: Main.barFont
                                            clip: true
                                            text: root.pskText
                                            onTextEdited: root.pskText = text
                                            onVisibleChanged: if (visible) forceActiveFocus()
                                            Component.onCompleted: if (visible) forceActiveFocus()
                                            Keys.onReturnPressed: join.clicked()
                                            Keys.onEscapePressed: {
                                                root.pskFor = "";
                                                modal.body.forceActiveFocus();
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: !root.pskText
                                                text: "password"
                                                color: Main.theme.colAccentDark
                                                font: Main.barFont
                                            }
                                        }
                                    }
                                    Rectangle {
                                        id: join
                                        signal clicked
                                        width: 84
                                        height: 32
                                        radius: Main.radius
                                        color: joinMouse.containsMouse ? Main.theme.colAccentLight : Main.theme.colFg
                                        onClicked: {
                                            if (!root.pskText)
                                                return;
                                            net.modelData.connectWithPsk(root.pskText);
                                            root.pskFor = "";
                                            modal.body.forceActiveFocus();
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Connect"
                                            color: Main.theme.colBg
                                            font: Main.barFont
                                        }
                                        MouseArea {
                                            id: joinMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: join.clicked()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.topMargin: Main.gap
                        visible: root.tab === "bluetooth"

                        Item {
                            id: btHead
                            width: parent.width
                            height: 28
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰂯  " + (Bt.adapter?.name ?? "Bluetooth")
                                color: Main.theme.colFg
                                font: Main.barFont
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: Bt.enabled
                                    height: 26
                                    width: scanRow.implicitWidth + 20
                                    radius: Main.radius
                                    color: Bt.scanning ? Main.theme.overlay(0.1) : (scanMouse.containsMouse ? Main.theme.overlay(0.08) : Main.theme.overlay(0.03))
                                    border.color: Main.theme.overlay(0.08)
                                    border.width: 1
                                    Row {
                                        id: scanRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: "󰑓"
                                            color: Bt.scanning ? Main.theme.colFg : Main.theme.colAccentLight
                                            font: Main.smallFont
                                            RotationAnimation on rotation {
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                                running: Bt.scanning && root.opened
                                            }
                                        }
                                        Text {
                                            text: Bt.scanning ? "Scanning" : "Scan"
                                            color: Bt.scanning ? Main.theme.colFg : Main.theme.colAccentLight
                                            font: Main.smallFont
                                        }
                                    }
                                    MouseArea {
                                        id: scanMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Bt.toggleScan()
                                    }
                                }
                                Switch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: Bt.enabled
                                    onToggled: Bt.toggle()
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !Bt.available || !Bt.enabled || Bt.devices.length === 0
                            text: !Bt.available ? "No Bluetooth adapter" : !Bt.enabled ? "Bluetooth is off" : "No devices yet, try Scan"
                            color: Main.theme.colAccentDark
                            font: Main.barFont
                        }

                        ListView {
                            anchors.top: btHead.bottom
                            anchors.topMargin: 12
                            anchors.bottom: parent.bottom
                            width: parent.width
                            visible: Bt.enabled
                            clip: true
                            spacing: 4
                            model: ScriptModel {
                                values: root.opened && root.tab === "bluetooth" ? Bt.devices : []
                            }
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: btDev
                                required property var modelData
                                readonly property bool busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                                width: ListView.view.width
                                height: 48
                                radius: Main.radius
                                color: modelData.connected ? Main.theme.overlay(0.06) : (devMouse.containsMouse ? Main.theme.overlay(0.05) : "transparent")
                                border.color: modelData.connected ? "transparent" : "transparent"
                                border.width: 1

                                MouseArea {
                                    id: devMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const d = btDev.modelData;
                                        if (d.connected)
                                            d.disconnect();
                                        else if (d.paired)
                                            d.connect();
                                        else
                                            d.pair();
                                    }
                                }

                                IconImage {
                                    id: devIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 22
                                    source: btDev.modelData.icon ? Quickshell.iconPath(btDev.modelData.icon, true) : ""
                                    visible: source != ""
                                }
                                Text {
                                    anchors.centerIn: devIcon
                                    visible: !devIcon.visible
                                    text: "󰂯"
                                    color: Main.theme.colAccentLight
                                    font: Main.iconFont
                                }
                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 46
                                    anchors.right: devActions.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        width: parent.width
                                        text: btDev.modelData.name
                                        color: Main.theme.colFg
                                        font: Main.barFont
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: {
                                            const d = btDev.modelData;
                                            if (d.pairing)
                                                return "Pairing…";
                                            if (d.state === BluetoothDeviceState.Connecting)
                                                return "Connecting…";
                                            if (d.state === BluetoothDeviceState.Disconnecting)
                                                return "Disconnecting…";
                                            const s = d.connected ? "Connected" : d.paired ? "Paired · click to connect" : "Click to pair";
                                            return d.batteryAvailable ? s + "  ·  󰁹 " + Math.round(d.battery * 100) + "%" : s;
                                        }
                                        color: btDev.modelData.connected ? Main.theme.colFg : Main.theme.colAccentMid
                                        font: Main.smallFont
                                        elide: Text.ElideRight
                                    }
                                }
                                Row {
                                    id: devActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    IconButton {
                                        visible: btDev.modelData.paired
                                        implicitWidth: 30
                                        implicitHeight: 30
                                        icon: "󰆴"
                                        iconFont: Main.barFont
                                        confirm: true
                                        onClicked: btDev.modelData.forget()
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.topMargin: Main.gap
                        visible: root.tab === "notifications"

                        Item {
                            id: notifHead
                            width: parent.width
                            height: 28
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Notifs.count === 0 ? "󰂚  No notifications" : "󰂚  " + Notifs.count + (Notifs.count === 1 ? " notification" : " notifications")
                                color: Main.theme.colFg
                                font: Main.barFont
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Silent"
                                    color: Main.theme.colAccentLight
                                    font: Main.smallFont
                                }
                                Switch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: Dnd.enabled
                                    onToggled: Dnd.toggle()
                                }
                                Chip {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: Notifs.count > 0
                                    text: "Clear all"
                                    clickable: true
                                    onClicked: Notifs.clearAll()
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: Notifs.count === 0
                            text: "You're all caught up"
                            color: Main.theme.colAccentDark
                            font: Main.barFont
                        }

                        ListView {
                            anchors.top: notifHead.bottom
                            anchors.topMargin: 12
                            anchors.bottom: parent.bottom
                            width: parent.width
                            clip: true
                            spacing: 8
                            boundsBehavior: Flickable.StopAtBounds
                            model: ScriptModel {
                                values: root.opened && root.tab === "notifications" ? Notifs.list : []
                            }
                            delegate: NotificationCard {
                                required property var modelData
                                width: ListView.view.width
                                notification: modelData
                                now: root.now
                            }
                        }

                        Timer {
                            interval: 30000
                            running: root.opened && root.tab === "notifications"
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: root.now = Date.now()
                        }
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
