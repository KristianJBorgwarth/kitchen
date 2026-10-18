pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import qs.core
import qs.services
import "components"

// Full system monitor: a centered card of islands over a dimmed screen.
Scope {
    id: root
    property bool opened: false

    readonly property font bigFont: Qt.font({
        family: Main.fontFamily,
        pixelSize: 40,
        weight: Font.Light
    })
    readonly property font midFont: Qt.font({
        family: Main.fontFamily,
        pixelSize: 22,
        weight: Font.Light
    })

    function show() {
        unmapTimer.stop();
        // open on the monitor sway has focused
        const focused = Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name);
        if (focused)
            win.screen = focused;
        win.visible = true;
        opened = true;
        Monitor.detailed = true;
    }

    function hide() {
        opened = false;
        Monitor.detailed = false;
        unmapTimer.restart();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    function gib(v) {
        return v.toFixed(1);
    }

    Timer {
        id: unmapTimer
        interval: 250
        onTriggered: {
            if (!root.opened)
                win.visible = false;
        }
    }

    PanelWindow {
        id: win
        visible: false
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-sysmon"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // dim + click-outside-to-close
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.opened ? 0.45 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(1240, parent.width - 80)
            height: Math.min(820, parent.height - 80)
            radius: 14
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1

            focus: true
            Keys.onEscapePressed: root.hide()

            scale: root.opened ? 1 : 0.94
            opacity: root.opened ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            // swallow clicks so they don't reach the backdrop
            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: layout
                anchors.fill: parent
                anchors.margins: 20

                readonly property real gap: 12
                readonly property real headerH: 48
                readonly property real rowsH: height - headerH - gap * 3
                readonly property real row1H: rowsH * 0.38
                readonly property real row2H: rowsH * 0.28
                readonly property real row3H: rowsH - row1H - row2H

                // ── header ────────────────────────────────────────────
                Item {
                    id: header
                    width: parent.width
                    height: layout.headerH

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: Monitor.host
                            color: Main.theme.colFg
                            font.family: Main.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: [Monitor.distro, Monitor.kernel, "up " + Monitor.uptime].filter(s => s).join("  ·  ")
                            color: Main.theme.colAccentMid
                            font: Main.smallFont
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // sample interval while open
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            width: intervalRow.implicitWidth + 6
                            radius: 14
                            color: Main.theme.colSurface

                            Row {
                                id: intervalRow
                                anchors.centerIn: parent
                                Repeater {
                                    model: Monitor.intervalChoices
                                    Rectangle {
                                        id: opt
                                        required property int modelData
                                        readonly property bool selected: Monitor.openInterval === modelData
                                        height: 22
                                        width: optText.implicitWidth + 16
                                        radius: 11
                                        color: opt.selected ? Main.theme.colFg : (optMouse.containsMouse ? Main.theme.colMuted : "transparent")

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }

                                        Text {
                                            id: optText
                                            anchors.centerIn: parent
                                            text: opt.modelData >= 1000 ? opt.modelData / 1000 + "s" : opt.modelData + "ms"
                                            color: opt.selected ? Main.theme.colBg : Main.theme.colAccentLight
                                            font: Main.smallFont
                                        }
                                        MouseArea {
                                            id: optMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Monitor.setOpenInterval(opt.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: [
                                { k: "load", v: Monitor.load.map(l => l.toFixed(2)).join("  ") },
                                { k: "procs", v: String(Monitor.procCount) }
                            ]
                            Rectangle {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                height: 28
                                width: chip.implicitWidth + 20
                                radius: 14
                                color: Main.theme.colSurface
                                Text {
                                    id: chip
                                    anchors.centerIn: parent
                                    textFormat: Text.StyledText
                                    text: "<font color='" + Main.theme.colAccentMid + "'>" + parent.modelData.k + "</font>  " + parent.modelData.v
                                    color: Main.theme.colFg
                                    font: Main.smallFont
                                }
                            }
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰅖"
                            onClicked: root.hide()
                        }
                    }
                }

                // ── row 1: cpu + memory ───────────────────────────────
                Row {
                    id: row1
                    anchors.top: header.bottom
                    anchors.topMargin: layout.gap
                    width: parent.width
                    height: layout.row1H
                    spacing: layout.gap

                    Island {
                        id: cpuIsland
                        width: (row1.width - layout.gap) * 0.64
                        height: parent.height
                        title: "Processor"
                        icon: "󰍛"
                        detail: Monitor.cpuModel

                        Column {
                            id: cpuStats
                            width: 210
                            height: parent.height
                            spacing: 6

                            Text {
                                text: Math.round(Monitor.cpuUsage) + "%"
                                color: Main.theme.colFg
                                font: root.bigFont
                            }
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [Monitor.cpuFreqGHz > 0 ? Monitor.cpuFreqGHz.toFixed(1) + " GHz" : "", Monitor.cpuTemp > 0 ? Monitor.cpuTemp + "°C" : "", Monitor.coreUsage.length + " threads"].filter(s => s)
                                    Rectangle {
                                        required property string modelData
                                        height: 22
                                        width: t.implicitWidth + 14
                                        radius: 11
                                        color: Main.theme.colMuted
                                        Text {
                                            id: t
                                            anchors.centerIn: parent
                                            text: parent.modelData
                                            color: Main.theme.colFg
                                            font: Main.smallFont
                                        }
                                    }
                                }
                            }
                        }

                        // per-core bars, bottom-left under the big number
                        Row {
                            id: cores
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            width: cpuStats.width
                            height: Math.max(24, parent.height - 100)
                            spacing: 3
                            readonly property real barW: (width - spacing * (Monitor.coreUsage.length - 1)) / Math.max(1, Monitor.coreUsage.length)

                            Repeater {
                                model: Monitor.coreUsage.length
                                Rectangle {
                                    required property int index
                                    readonly property real v: Monitor.coreUsage[index] ?? 0
                                    anchors.bottom: parent.bottom
                                    width: cores.barW
                                    height: cores.height
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.04)

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(2, parent.height * parent.v / 100)
                                        radius: 2
                                        color: Qt.rgba(Main.theme.colFg.r, Main.theme.colFg.g, Main.theme.colFg.b, 0.35 + 0.65 * parent.v / 100)

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 180
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Graph {
                            anchors.left: cpuStats.right
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            values: Monitor.cpuHistory
                            times: Monitor.historyTimes
                            window: Monitor.historyWindow
                        }
                    }

                    Island {
                        width: (row1.width - layout.gap) * 0.36
                        height: parent.height
                        title: "Memory"
                        icon: "󰘚"
                        detail: Math.round(Monitor.memUsage) + "%"

                        Column {
                            id: memStats
                            width: parent.width
                            spacing: 10

                            Text {
                                textFormat: Text.StyledText
                                text: root.gib(Monitor.memUsed) + "<font color='" + Main.theme.colAccentDark + "'> / " + root.gib(Monitor.memTotal) + " GiB</font>"
                                color: Main.theme.colFg
                                font: root.midFont
                            }

                            Meter {
                                width: parent.width
                                height: 8
                                max: Monitor.memTotal
                                segments: [
                                    { value: Monitor.memUsed, color: Main.theme.colFg },
                                    { value: Monitor.memCache, color: Main.theme.colAccentDark }
                                ]
                            }

                            Row {
                                spacing: 14
                                Repeater {
                                    model: [
                                        { c: Main.theme.colFg, l: "used " + root.gib(Monitor.memUsed) },
                                        { c: Main.theme.colAccentDark, l: "cache " + root.gib(Monitor.memCache) },
                                        { c: Main.theme.colMuted, l: "swap " + root.gib(Monitor.swapUsed) + "/" + root.gib(Monitor.swapTotal) }
                                    ]
                                    Row {
                                        required property var modelData
                                        spacing: 5
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 7
                                            height: 7
                                            radius: 4
                                            color: parent.modelData.c
                                        }
                                        Text {
                                            text: parent.modelData.l
                                            color: Main.theme.colAccentMid
                                            font: Main.smallFont
                                        }
                                    }
                                }
                            }
                        }

                        Graph {
                            anchors.top: memStats.bottom
                            anchors.topMargin: 12
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            values: Monitor.memHistory
                            times: Monitor.historyTimes
                            window: Monitor.historyWindow
                        }
                    }
                }

                // ── row 2: gpu + network + disk io ────────────────────
                Row {
                    id: row2
                    anchors.top: row1.bottom
                    anchors.topMargin: layout.gap
                    width: parent.width
                    height: layout.row2H
                    spacing: layout.gap
                    readonly property real islandW: (width - spacing * 2) / 3

                    Island {
                        width: row2.islandW
                        height: parent.height
                        title: "Graphics"
                        icon: "󰢮"
                        detail: Monitor.gpuName

                        Text {
                            anchors.centerIn: parent
                            visible: Monitor.gpuVendor === ""
                            text: "No GPU stats on this machine"
                            color: Main.theme.colAccentDark
                            font: Main.barFont
                        }

                        Item {
                            anchors.fill: parent
                            visible: Monitor.gpuVendor !== ""

                            Column {
                                id: gpuStats
                                width: 120
                                spacing: 4
                                Text {
                                    text: Math.round(Monitor.gpuUsage) + "%"
                                    color: Main.theme.colFg
                                    font: root.midFont
                                }
                                Text {
                                    visible: Monitor.gpuTemp > 0
                                    text: Monitor.gpuTemp + "°C"
                                    color: Main.theme.colAccentMid
                                    font: Main.smallFont
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                width: gpuStats.width - 12
                                spacing: 4
                                visible: Monitor.vramTotal > 0
                                Text {
                                    text: "VRAM " + root.gib(Monitor.vramUsed) + "/" + root.gib(Monitor.vramTotal)
                                    color: Main.theme.colAccentMid
                                    font: Main.smallFont
                                }
                                Meter {
                                    width: parent.width
                                    height: 4
                                    max: Monitor.vramTotal
                                    segments: [{ value: Monitor.vramUsed, color: Main.theme.colAccentLight }]
                                }
                            }

                            Graph {
                                anchors.left: gpuStats.right
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                values: Monitor.gpuHistory
                                times: Monitor.historyTimes
                                window: Monitor.historyWindow
                            }
                        }
                    }

                    Island {
                        width: row2.islandW
                        height: parent.height
                        title: "Network"
                        icon: "󰛳"
                        detail: Monitor.netIface

                        Column {
                            id: netStats
                            width: 120
                            spacing: 6
                            Text {
                                text: "↓ " + Monitor.fmtRate(Monitor.netRx)
                                color: Main.theme.colFg
                                font: Main.barFont
                            }
                            Text {
                                text: "↑ " + Monitor.fmtRate(Monitor.netTx)
                                color: Main.theme.colAccentMid
                                font: Main.barFont
                            }
                        }

                        Graph {
                            anchors.left: netStats.right
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            max: 0
                            values: Monitor.netRxHistory
                            values2: Monitor.netTxHistory
                            times: Monitor.historyTimes
                            window: Monitor.historyWindow
                        }
                    }

                    Island {
                        width: row2.islandW
                        height: parent.height
                        title: "Disk I/O"
                        icon: "󰋊"

                        Column {
                            id: ioStats
                            width: 120
                            spacing: 6
                            Text {
                                text: "R " + Monitor.fmtRate(Monitor.diskRead)
                                color: Main.theme.colFg
                                font: Main.barFont
                            }
                            Text {
                                text: "W " + Monitor.fmtRate(Monitor.diskWrite)
                                color: Main.theme.colAccentMid
                                font: Main.barFont
                            }
                        }

                        Graph {
                            anchors.left: ioStats.right
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            max: 0
                            values: Monitor.diskReadHistory
                            values2: Monitor.diskWriteHistory
                            times: Monitor.historyTimes
                            window: Monitor.historyWindow
                        }
                    }
                }

                // ── row 3: processes + storage + sensors ──────────────
                Row {
                    id: row3
                    anchors.top: row2.bottom
                    anchors.topMargin: layout.gap
                    width: parent.width
                    height: layout.row3H
                    spacing: layout.gap

                    Island {
                        id: procIsland
                        width: (row3.width - layout.gap * 2) * 0.5
                        height: parent.height
                        title: "Processes"
                        icon: "󰑮"
                        detail: "by cpu"

                        Column {
                            anchors.fill: parent
                            spacing: 0
                            readonly property real rowH: height / 9

                            Item {
                                width: parent.width
                                height: parent.rowH
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "NAME"
                                    color: Main.theme.colAccentDark
                                    font: Main.smallFont
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 90
                                    text: "CPU"
                                    color: Main.theme.colAccentDark
                                    font: Main.smallFont
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    text: "MEMORY"
                                    color: Main.theme.colAccentDark
                                    font: Main.smallFont
                                }
                            }

                            Repeater {
                                model: Monitor.processes
                                Item {
                                    required property var modelData
                                    width: parent.width
                                    height: parent.rowH

                                    // cpu share shown as a soft bar behind the row
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height - 4
                                        width: parent.width * Math.min(1, parent.modelData.cpu / 100)
                                        radius: 4
                                        color: Qt.rgba(1, 1, 1, 0.05)

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 400
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 170
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData.name + "<font color='" + Main.theme.colAccentDark + "'>  " + parent.modelData.pid + "</font>"
                                        textFormat: Text.StyledText
                                        color: Main.theme.colFg
                                        font: Main.barFont
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 90
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData.cpu.toFixed(1) + "%"
                                        color: Main.theme.colFg
                                        font: Main.barFont
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData.mem >= 1024 ? (parent.modelData.mem / 1024).toFixed(1) + " G" : parent.modelData.mem + " M"
                                        color: Main.theme.colAccentMid
                                        font: Main.barFont
                                    }
                                }
                            }
                        }
                    }

                    Island {
                        width: (row3.width - layout.gap * 2) * 0.25
                        height: parent.height
                        title: "Storage"
                        icon: "󰋊"

                        Column {
                            width: parent.width
                            spacing: 14
                            Repeater {
                                model: Monitor.mounts
                                Column {
                                    required property var modelData
                                    width: parent.width
                                    spacing: 6
                                    Item {
                                        width: parent.width
                                        height: mountName.implicitHeight
                                        Text {
                                            id: mountName
                                            width: parent.width - mountSize.implicitWidth - 8
                                            text: parent.parent.modelData.mount
                                            color: Main.theme.colFg
                                            font: Main.barFont
                                            elide: Text.ElideMiddle
                                        }
                                        Text {
                                            id: mountSize
                                            anchors.right: parent.right
                                            text: Math.round(parent.parent.modelData.used) + " / " + Math.round(parent.parent.modelData.total) + " G"
                                            color: Main.theme.colAccentMid
                                            font: Main.smallFont
                                        }
                                    }
                                    Meter {
                                        width: parent.width
                                        height: 6
                                        max: parent.modelData.total
                                        segments: [{ value: parent.modelData.used, color: Main.theme.colAccentLight }]
                                    }
                                }
                            }
                        }
                    }

                    Island {
                        width: (row3.width - layout.gap * 2) * 0.25
                        height: parent.height
                        title: "Sensors"
                        icon: "󰔏"

                        Column {
                            anchors.fill: parent
                            spacing: 0
                            readonly property real rowH: Math.min(28, height / Math.max(1, Monitor.sensors.length))

                            Repeater {
                                model: Monitor.sensors
                                Item {
                                    required property var modelData
                                    width: parent.width
                                    height: parent.rowH
                                    // hotter reads brighter; 30°C and below sits at the dim end
                                    readonly property real heat: Math.max(0, Math.min(1, (modelData.temp - 30) / 60))

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData.name
                                        color: Main.theme.colAccentLight
                                        font: Main.barFont
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: tempText.left
                                        anchors.rightMargin: 10
                                        width: 60
                                        height: 4
                                        radius: 2
                                        color: Main.theme.colMuted
                                        Rectangle {
                                            width: parent.width * Math.min(1, parent.parent.modelData.temp / 100)
                                            height: parent.height
                                            radius: 2
                                            color: Qt.rgba(1, 1, 1, 0.35 + 0.65 * parent.parent.heat)
                                        }
                                    }
                                    Text {
                                        id: tempText
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 40
                                        horizontalAlignment: Text.AlignRight
                                        text: parent.modelData.temp + "°"
                                        color: Qt.rgba(1, 1, 1, 0.55 + 0.45 * parent.heat)
                                        font: Main.barFont
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
