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
        calendar.offset = 0;
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
        target: Network
        property: "scanning"
        value: root.opened && root.tab === "network"
    }

    Modal {
        id: modal
        maxWidth: 1120
        maxHeight: 760
        padding: 24
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
            { keys: "[", desc: "previous month", run: () => calendar.shift(-1) },
            { keys: "]", desc: "next month", run: () => calendar.shift(1) },
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

                Rectangle {
                    width: parent.width
                    height: 138
                    radius: Main.radius
                    color: Main.theme.colSurface
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 4

                        Text {
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: Main.theme.colFg
                            font.family: Main.fontFamily
                            font.pixelSize: 38
                            font.weight: Font.Light
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
                        anchors.margins: 20
                        visible: root.hasBattery
                        height: 24
                        width: battText.implicitWidth + 20
                        radius: Main.radius
                        readonly property color tint: root.batteryLevel < 0.15 ? Main.theme.colRed : root.batteryLevel < 0.35 ? Main.theme.colAmber : Main.theme.colGreen
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

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Main.radius
                    color: Main.theme.colSurface
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1

                    Row {
                        id: powerRow
                        anchors.fill: parent
                        anchors.margins: 6
                        Repeater {
                            model: [
                                { icon: "󰌾", confirm: false, danger: false, run: () => { root.hide(); Lock.lock(); } },
                                { icon: "󰤄", confirm: false, danger: false, run: () => { root.hide(); Lock.suspend(); } },
                                { icon: "󰍃", confirm: true, danger: true, run: () => Session.logout() },
                                { icon: "󰜉", confirm: true, danger: true, run: () => Session.reboot() },
                                { icon: "󰐥", confirm: true, danger: true, run: () => Session.poweroff() }
                            ]
                            IconButton {
                                required property var modelData
                                implicitWidth: powerRow.width / 5
                                implicitHeight: powerRow.height
                                radius: Main.radius
                                icon: modelData.icon
                                confirm: modelData.confirm
                                armedColor: modelData.danger ? Main.theme.colRed : Main.theme.colFg
                                onClicked: modelData.run()
                            }
                        }
                    }
                }

                Grid {
                    id: tiles
                    width: parent.width
                    columns: 2
                    spacing: 12
                    readonly property real tileW: (width - spacing) / 2

                    ToggleTile {
                        width: tiles.tileW
                        accent: Main.theme.colBlue
                        icon: Network.hasWifi ? (Network.wifiEnabled ? "󰤨" : "󰤭") : "󰈀"
                        label: Network.hasWifi ? "Wi-Fi" : "Network"
                        sublabel: Network.hasWifi && !Network.wifiEnabled ? (Network.wired ? "Off · wired" : "Off") : Network.label
                        active: Network.hasWifi ? Network.wifiEnabled : Network.connected
                        clickable: Network.hasWifi
                        hasDetails: true
                        onClicked: Network.toggleWifi()
                        onDetailsClicked: root.openTab("network")
                    }
                    ToggleTile {
                        width: tiles.tileW
                        visible: Bt.available
                        accent: Main.theme.colViolet
                        icon: Bt.enabled ? "󰂯" : "󰂲"
                        label: "Bluetooth"
                        sublabel: Bt.label
                        active: Bt.enabled
                        hasDetails: true
                        onClicked: Bt.toggle()
                        onDetailsClicked: root.openTab("bluetooth")
                    }
                    ToggleTile {
                        width: tiles.tileW
                        accent: Main.theme.colRed
                        icon: Dnd.enabled ? "󰂛" : "󰂚"
                        label: "Silent"
                        sublabel: Dnd.enabled ? "Don't disturb" : "Off"
                        active: Dnd.enabled
                        onClicked: Dnd.toggle()
                    }
                    ToggleTile {
                        width: tiles.tileW
                        accent: Main.theme.colAmber
                        icon: "󰈈"
                        label: "Stay awake"
                        sublabel: Awake.enabled ? "On" : "Off"
                        active: Awake.enabled
                        onClicked: Awake.enabled = !Awake.enabled
                    }
                    ToggleTile {
                        width: tiles.tileW
                        visible: NightLight.available
                        accent: Main.theme.colAmber
                        icon: "󰖔"
                        label: "Night light"
                        sublabel: NightLight.enabled ? NightLight.temperature + "K" : "Off"
                        active: NightLight.enabled
                        onClicked: NightLight.toggle()
                    }
                    ToggleTile {
                        width: tiles.tileW
                        readonly property bool muted: Audio.source?.audio?.muted ?? false
                        accent: Main.theme.colTeal
                        icon: muted ? "󰍭" : "󰍬"
                        label: "Microphone"
                        sublabel: muted ? "Muted" : "On"
                        active: !muted
                        onClicked: Audio.toggleMute(Audio.source)
                    }
                }

                // night light warmth, while it's on
                Rectangle {
                    visible: NightLight.available && NightLight.enabled
                    width: parent.width
                    height: 44
                    radius: Main.radius
                    color: Main.theme.colSurface
                    SliderRow {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        icon: "󰖔"
                        accent: Main.theme.colAmber
                        // warmer to the right: 6000K → 2500K
                        value: (6000 - NightLight.temperature) / 3500
                        onMoved: v => NightLight.setTemperature(6000 - v * 3500)
                    }
                }

                Rectangle {
                    visible: PowerProfile.available
                    width: parent.width
                    height: 40
                    radius: Main.radius
                    color: Main.theme.colSurface

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        Repeater {
                            model: [
                                { id: "power-saver", icon: "󰾆", label: "Saver", tint: Main.theme.colGreen },
                                { id: "balanced", icon: "󰾅", label: "Balanced", tint: Main.theme.colBlue },
                                { id: "performance", icon: "󰓅", label: "Performance", tint: Main.theme.colAmber }
                            ]
                            delegate: Rectangle {
                                id: seg
                                required property var modelData
                                readonly property bool selected: PowerProfile.current === modelData.id
                                width: parent.width / 3
                                height: parent.height
                                radius: Main.radius
                                color: selected ? Qt.rgba(modelData.tint.r, modelData.tint.g, modelData.tint.b, 0.2) : (segMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.color: selected ? Qt.rgba(modelData.tint.r, modelData.tint.g, modelData.tint.b, 0.5) : "transparent"
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Main.anim
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: seg.modelData.icon + "  " + seg.modelData.label
                                    color: seg.selected ? seg.modelData.tint : Main.theme.colFg
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
                    height: 44
                    radius: Main.radius
                    color: Main.theme.colSurface
                    SliderRow {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        icon: "󰃠"
                        accent: Main.theme.colAmber
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: leftCol.height - y
                    radius: Main.radius
                    color: Main.theme.colSurface
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1

                    MonthCalendar {
                        id: calendar
                        anchors.fill: parent
                        anchors.margins: 14
                        accent: Main.theme.colBlue
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
                        width: 540
                        height: 40
                        radius: Main.radius
                        color: Main.theme.colSurface

                        readonly property var defs: [
                            { id: "sound", icon: "󰕾", label: "Sound", tint: Main.theme.colGreen },
                            { id: "network", icon: "󰛳", label: "Network", tint: Main.theme.colBlue },
                            { id: "bluetooth", icon: "󰂯", label: "Bluetooth", tint: Main.theme.colViolet },
                            { id: "notifications", icon: "󰂚", label: "Notifications", tint: Main.theme.colAmber }
                        ]
                        readonly property int index: root.tabs.indexOf(root.tab)

                        Rectangle {
                            x: 4 + tabTrack.index * (tabTrack.width - 8) / tabTrack.defs.length
                            y: 4
                            width: (tabTrack.width - 8) / tabTrack.defs.length
                            height: tabTrack.height - 8
                            radius: Main.radius
                            readonly property color tint: tabTrack.defs[tabTrack.index].tint
                            color: Qt.rgba(tint.r, tint.g, tint.b, 0.2)
                            border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.5)
                            border.width: 1

                            Behavior on x {
                                NumberAnimation {
                                    duration: Main.anim
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Main.anim
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 4
                            Repeater {
                                model: tabTrack.defs
                                Item {
                                    id: tabItem
                                    required property var modelData
                                    width: parent.width / tabTrack.defs.length
                                    height: parent.height
                                    Text {
                                        anchors.centerIn: parent
                                        text: tabItem.modelData.icon + "  " + tabItem.modelData.label
                                        color: root.tab === tabItem.modelData.id ? tabItem.modelData.tint : Main.theme.colAccentLight
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

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "? keys"
                            color: Main.theme.colAccentDark
                            font: Main.smallFont
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰅖"
                            onClicked: root.hide()
                        }
                    }
                }

                Rectangle {
                    id: pane
                    anchors.top: tabBar.bottom
                    anchors.topMargin: 14
                    anchors.bottom: media.visible ? media.top : parent.bottom
                    anchors.bottomMargin: media.visible ? 14 : 0
                    width: parent.width
                    radius: Main.radius
                    color: Main.theme.colSurface
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 20
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
                                    { title: "Output", output: true, tint: Main.theme.colGreen, on: "󰕾", off: "󰝟" },
                                    { title: "Input", output: false, tint: Main.theme.colTeal, on: "󰍬", off: "󰍭" }
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
                                        accent: Main.theme.colBlue
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
                        anchors.margins: 20
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
                                    color: Network.wiredDevice?.connected ? Main.theme.colGreen : Main.theme.colMuted
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
                                        accent: Main.theme.colBlue
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
                                color: modelData.connected ? Qt.rgba(Main.theme.colBlue.r, Main.theme.colBlue.g, Main.theme.colBlue.b, 0.12) : (netMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.color: modelData.connected ? Qt.rgba(Main.theme.colBlue.r, Main.theme.colBlue.g, Main.theme.colBlue.b, 0.35) : "transparent"
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
                                        color: net.modelData.connected ? Main.theme.colBlue : Main.theme.colAccentLight
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
                                            color: net.modelData.connected ? Main.theme.colBlue : Main.theme.colAccentMid
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
                                        border.color: psk.activeFocus ? Main.theme.colBlue : Main.theme.colMuted
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
                                        color: joinMouse.containsMouse ? Qt.lighter(Main.theme.colBlue, 1.1) : Main.theme.colBlue
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
                        anchors.margins: 20
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
                                    color: Bt.scanning ? Qt.rgba(Main.theme.colViolet.r, Main.theme.colViolet.g, Main.theme.colViolet.b, 0.18) : (scanMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                                    border.color: Bt.scanning ? Main.theme.colViolet : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    Row {
                                        id: scanRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: "󰑓"
                                            color: Bt.scanning ? Main.theme.colViolet : Main.theme.colAccentLight
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
                                            color: Bt.scanning ? Main.theme.colViolet : Main.theme.colAccentLight
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
                                    accent: Main.theme.colViolet
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
                                color: modelData.connected ? Qt.rgba(Main.theme.colViolet.r, Main.theme.colViolet.g, Main.theme.colViolet.b, 0.12) : (devMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.color: modelData.connected ? Qt.rgba(Main.theme.colViolet.r, Main.theme.colViolet.g, Main.theme.colViolet.b, 0.35) : "transparent"
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
                                        color: btDev.modelData.connected ? Main.theme.colViolet : Main.theme.colAccentMid
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
                        anchors.margins: 20
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
                                    accent: Main.theme.colRed
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

                MediaCard {
                    id: media
                    anchors.bottom: parent.bottom
                    width: parent.width
                    visible: Media.player !== null
                    player: Media.player
                    radius: Main.radius

                    // the card's own buttons sit above this, so it only catches clicks elsewhere
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicPlayer.show()
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
