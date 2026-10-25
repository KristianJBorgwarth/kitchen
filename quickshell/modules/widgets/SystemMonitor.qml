pragma Singleton

import QtQuick
import Quickshell
import qs.core
import qs.core.components
import qs.services
import "components"

Scope {
    id: root
    readonly property alias opened: modal.opened

    readonly property font bigFont: Main.heroFont
    readonly property font midFont: Main.displayFont

    function show() {
        Monitor.detailed = true;
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

    function fmtMem(m) {
        return m >= 1024 ? (m / 1024).toFixed(1) + " G" : Math.round(m) + " M";
    }

    function gib(v) {
        return v.toFixed(1);
    }

    readonly property bool focusing: Monitor.focused
    readonly property string focusLabel: "“" + Monitor.procFilter + "”"
    property string selectedPid: ""
    property string armedPid: ""

    readonly property var selectedProc: Monitor.processes.find(p => p.pid === selectedPid) ?? null

    function heatColor(frac) {
        return frac > 0.85 ? Main.theme.colRed : frac > 0.6 ? Main.theme.colAmber : Main.theme.colGreen;
    }

    function moveSelection(d) {
        const procs = Monitor.processes;
        if (procs.length === 0)
            return;
        const i = procs.findIndex(p => p.pid === selectedPid);
        selectedPid = procs[Math.max(0, Math.min(procs.length - 1, i < 0 ? (d > 0 ? 0 : procs.length - 1) : i + d))].pid;
        armedPid = "";
    }

    // first press arms, second press sends the signal
    function endSelected(sig) {
        if (!selectedProc)
            return;
        if (armedPid === selectedPid + sig) {
            Monitor.signalProc(selectedPid, sig);
            armedPid = "";
            selectedPid = "";
        } else {
            armedPid = selectedPid + sig;
        }
    }

    function stepInterval(d) {
        const choices = Monitor.intervalChoices;
        const i = choices.indexOf(Monitor.openInterval);
        Monitor.setOpenInterval(choices[Math.max(0, Math.min(choices.length - 1, i + d))]);
    }

    Modal {
        id: modal
        framed: true
        maxWidth: 1240
        maxHeight: 840
        padding: Main.pad

        actions: [
            Text {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 8
                text: [Monitor.distro, Monitor.kernel, "up " + Monitor.uptime, "load " + Monitor.load.map(l => l.toFixed(2)).join(" "), Monitor.procCount + " procs"].filter(s => s).join("  ·  ")
                color: Main.theme.colAccentDark
                font: Main.smallFont
            },
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                text: Monitor.paused ? "󰐊  paused" : "󰏤  live"
                tint: Monitor.paused ? Main.theme.colAmber : Main.theme.colGreen
                active: true
                clickable: true
                onClicked: Monitor.paused = !Monitor.paused
            },
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: Monitor.intervalChoices
                    Chip {
                        required property int modelData
                        padding: 8
                        text: modelData >= 1000 ? modelData / 1000 + "s" : modelData + "ms"
                        active: Monitor.openInterval === modelData
                        clickable: true
                        onClicked: Monitor.setOpenInterval(modelData)
                    }
                }
            }
        ]
        onClosed: {
            Monitor.detailed = false;
            Monitor.paused = false;
            root.selectedPid = "";
            root.armedPid = "";
            search.text = "";
        }
        bindings: [
            { keys: "p", desc: "pause / resume", run: () => Monitor.paused = !Monitor.paused },
            { keys: "<Space>", desc: "pause / resume", run: () => Monitor.paused = !Monitor.paused },
            { keys: "/", desc: "search processes", run: () => search.forceActiveFocus() },
            { keys: "s", desc: "sort processes by cpu / memory", run: () => Monitor.toggleSort() },
            { keys: "j", desc: "select next process", run: () => root.moveSelection(1) },
            { keys: "k", desc: "select previous process", run: () => root.moveSelection(-1) },
            { keys: "<Down>", desc: "", run: () => root.moveSelection(1) },
            { keys: "<Up>", desc: "", run: () => root.moveSelection(-1) },
            { keys: "x", desc: "end process (press twice)", run: () => root.endSelected("TERM") },
            { keys: "X", desc: "kill process (press twice)", run: () => root.endSelected("KILL") },
            { keys: "+", desc: "update faster", run: () => root.stepInterval(-1) },
            { keys: "-", desc: "update slower", run: () => root.stepInterval(1) },
            { keys: "1", desc: "every 100ms", run: () => Monitor.setOpenInterval(100) },
            { keys: "2", desc: "every 200ms", run: () => Monitor.setOpenInterval(200) },
            { keys: "3", desc: "every 500ms", run: () => Monitor.setOpenInterval(500) },
            { keys: "4", desc: "every second", run: () => Monitor.setOpenInterval(1000) }
        ]

        Item {
            id: layout
            anchors.fill: parent

            readonly property real gap: Main.pad
            readonly property real rowsH: height - gap * 2
            readonly property real row1H: rowsH * 0.34
            readonly property real row2H: rowsH * 0.24
            readonly property real row3H: rowsH - row1H - row2H

            Row {
                id: row1
                anchors.top: parent.top
                width: parent.width
                height: layout.row1H
                spacing: layout.gap

                Island {
                    id: cpuIsland
                    width: (row1.width - layout.gap) * 0.64
                    height: parent.height
                    title: "Processor"
                    icon: "󰍛"
                    detail: root.focusing ? root.focusLabel + " · " + Monitor.focusCount + " procs" : Monitor.cpuModel

                    Column {
                        id: cpuStats
                        width: 210
                        height: parent.height
                        spacing: 6

                        Text {
                            text: root.focusing ? Monitor.focusCpu.toFixed(1) + "%" : Math.round(Monitor.cpuUsage) + "%"
                            color: Main.theme.colFg
                            font: root.bigFont
                        }
                        Row {
                            spacing: 6
                            Repeater {
                                model: root.focusing ? [Monitor.focusCount + " processes", "of " + Monitor.coreUsage.length + " threads"] : [Monitor.cpuFreqGHz > 0 ? Monitor.cpuFreqGHz.toFixed(1) + " GHz" : "", Monitor.cpuTemp > 0 ? Monitor.cpuTemp + "°C" : "", Monitor.coreUsage.length + " threads"].filter(s => s)
                                Rectangle {
                                    required property string modelData
                                    height: 22
                                    width: t.implicitWidth + 14
                                    radius: Main.radius
                                    color: Main.theme.overlay(0.06)
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

                    Row {
                        id: cores
                        visible: !root.focusing
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
                                color: coreHover.hovered ? Main.theme.overlay(0.1) : Main.theme.overlay(0.04)

                                HoverHandler {
                                    id: coreHover
                                }

                                Text {
                                    visible: coreHover.hovered
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 3
                                    z: 2
                                    text: parent.index + ": " + Math.round(parent.v) + "%"
                                    color: Main.theme.colFg
                                    font: Main.smallFont
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, parent.height * parent.v / 100)
                                    radius: 2
                                    color: Qt.rgba(Main.theme.colBlue.r, Main.theme.colBlue.g, Main.theme.colBlue.b, 0.35 + 0.65 * parent.v / 100)

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
                        values: root.focusing ? Monitor.focusCpuHistory : Monitor.cpuHistory
                        color: Main.theme.colBlue
                        times: root.focusing ? Monitor.focusTimes : Monitor.historyTimes
                        window: Monitor.historyWindow
                    }
                }

                Island {
                    width: (row1.width - layout.gap) * 0.36
                    height: parent.height
                    title: "Memory"
                    icon: "󰘚"
                    detail: root.focusing ? root.focusLabel : Math.round(Monitor.memUsage) + "%"

                    Column {
                        id: memStats
                        width: parent.width
                        spacing: 10

                        Text {
                            textFormat: Text.StyledText
                            text: root.gib(root.focusing ? Monitor.focusMem : Monitor.memUsed) + "<font color='" + Main.theme.colAccentDark + "'> / " + root.gib(Monitor.memTotal) + " GiB</font>"
                            color: Main.theme.colFg
                            font: root.midFont
                        }

                        Meter {
                            width: parent.width
                            height: 8
                            max: Monitor.memTotal
                            segments: [
                                { value: root.focusing ? Monitor.focusMem : Monitor.memUsed, color: Main.theme.colViolet },
                                { value: root.focusing ? 0 : Monitor.memCache, color: Main.theme.colAccentDark }
                            ]
                        }

                        Row {
                            spacing: 14
                            visible: !root.focusing
                            Repeater {
                                model: [
                                    { c: Main.theme.colViolet, l: "used " + root.gib(Monitor.memUsed) },
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
                        values: root.focusing ? Monitor.focusMemHistory : Monitor.memHistory
                        color: Main.theme.colViolet
                        times: root.focusing ? Monitor.focusTimes : Monitor.historyTimes
                        window: Monitor.historyWindow
                    }
                }
            }

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
                    detail: root.focusing ? root.focusLabel : Monitor.gpuName

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
                                text: Math.round(root.focusing ? Monitor.focusGpu : Monitor.gpuUsage) + "%"
                                color: Main.theme.colFg
                                font: root.midFont
                            }
                            Text {
                                visible: Monitor.gpuTemp > 0 && !root.focusing
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
                                text: "VRAM " + root.gib(root.focusing ? Monitor.focusVram : Monitor.vramUsed) + "/" + root.gib(Monitor.vramTotal)
                                color: Main.theme.colAccentMid
                                font: Main.smallFont
                            }
                            Meter {
                                width: parent.width
                                height: 4
                                max: Monitor.vramTotal
                                segments: [{ value: root.focusing ? Monitor.focusVram : Monitor.vramUsed, color: Main.theme.colGreen }]
                            }
                        }

                        Graph {
                            anchors.left: gpuStats.right
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            values: root.focusing ? Monitor.focusGpuHistory : Monitor.gpuHistory
                            color: Main.theme.colGreen
                            times: root.focusing ? Monitor.focusTimes : Monitor.historyTimes
                            window: Monitor.historyWindow
                        }
                    }
                }

                Island {
                    width: row2.islandW
                    height: parent.height
                    title: "Network"
                    icon: "󰛳"
                    detail: root.focusing ? root.focusLabel + " · tcp" : Monitor.netIface

                    Column {
                        id: netStats
                        width: 120
                        spacing: 6
                        Text {
                            text: "↓ " + Monitor.fmtRate(root.focusing ? Monitor.focusRx : Monitor.netRx)
                            color: Main.theme.colTeal
                            font: Main.barFont
                        }
                        Text {
                            text: "↑ " + Monitor.fmtRate(root.focusing ? Monitor.focusTx : Monitor.netTx)
                            color: Main.theme.colAmber
                            font: Main.barFont
                        }
                    }

                    Graph {
                        anchors.left: netStats.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        max: 0
                        values: root.focusing ? Monitor.focusRxHistory : Monitor.netRxHistory
                        values2: root.focusing ? Monitor.focusTxHistory : Monitor.netTxHistory
                        color: Main.theme.colTeal
                        color2: Main.theme.colAmber
                        format: Monitor.fmtRate
                        label: "↓ "
                        label2: "↑ "
                        times: root.focusing ? Monitor.focusTimes : Monitor.historyTimes
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
                            text: "R " + Monitor.fmtRate(root.focusing ? Monitor.focusRead : Monitor.diskRead)
                            color: Main.theme.colTeal
                            font: Main.barFont
                        }
                        Text {
                            text: "W " + Monitor.fmtRate(root.focusing ? Monitor.focusWrite : Monitor.diskWrite)
                            color: Main.theme.colAmber
                            font: Main.barFont
                        }
                    }

                    Graph {
                        anchors.left: ioStats.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        max: 0
                        values: root.focusing ? Monitor.focusReadHistory : Monitor.diskReadHistory
                        values2: root.focusing ? Monitor.focusWriteHistory : Monitor.diskWriteHistory
                        color: Main.theme.colTeal
                        color2: Main.theme.colAmber
                        format: Monitor.fmtRate
                        label: "R "
                        label2: "W "
                        times: root.focusing ? Monitor.focusTimes : Monitor.historyTimes
                        window: Monitor.historyWindow
                    }
                }
            }

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
                    detail: root.armedPid && root.selectedProc ? "press again to " + (root.armedPid.endsWith("KILL") ? "kill " : "end ") + root.selectedProc.name : Monitor.procFilter ? Monitor.procTotals.count + " match  ·  " + Monitor.procTotals.cpu.toFixed(1) + "% cpu  ·  " + root.fmtMem(Monitor.procTotals.mem) : root.selectedProc ? "x end  ·  X kill  ·  j/k move" : "/ search  ·  s sorts"

                    Column {
                        anchors.fill: parent
                        spacing: 0
                        readonly property real rowH: height / (Monitor.procLimit + 2)

                        Rectangle {
                            width: parent.width
                            height: parent.rowH - 2
                            radius: Main.radius
                            color: Main.theme.overlay(search.activeFocus ? 0.08 : 0.04)
                            border.color: search.activeFocus ? Main.theme.colAccentMid : Main.theme.overlay(0.08)
                            border.width: 1

                            Text {
                                id: searchIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰍉"
                                color: Main.theme.colAccentMid
                                font: Main.smallFont
                            }
                            TextInput {
                                id: search
                                anchors.left: searchIcon.right
                                anchors.leftMargin: 8
                                anchors.right: clearBtn.left
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                color: Main.theme.colFg
                                font: Main.barFont
                                selectByMouse: true
                                onTextChanged: Monitor.procFilter = text.trim()
                                Keys.onEscapePressed: {
                                    text = "";
                                    modal.body.forceActiveFocus();
                                }
                                Keys.onReturnPressed: modal.body.forceActiveFocus()
                                Keys.onDownPressed: {
                                    modal.body.forceActiveFocus();
                                    root.moveSelection(1);
                                }

                                Text {
                                    visible: !search.text && !search.activeFocus
                                    text: "search processes  ( / )"
                                    color: Main.theme.colAccentDark
                                    font: Main.barFont
                                }
                            }
                            Text {
                                id: clearBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text !== ""
                                text: "󰅖"
                                color: Main.theme.colAccentMid
                                font: Main.smallFont
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        search.text = "";
                                        modal.body.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: parent.rowH
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "NAME"
                                color: Main.theme.colAccentDark
                                font: Main.smallFont
                            }
                            Repeater {
                                model: [
                                    { key: "cpu", label: "CPU", margin: 90 },
                                    { key: "mem", label: "MEMORY", margin: 0 }
                                ]
                                Text {
                                    required property var modelData
                                    readonly property bool on: Monitor.procSort === modelData.key
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: modelData.margin
                                    text: modelData.label + (on ? " ▾" : "")
                                    color: on ? Main.theme.colFg : (headMouse.containsMouse ? Main.theme.colAccentLight : Main.theme.colAccentDark)
                                    font: Main.smallFont

                                    MouseArea {
                                        id: headMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (!parent.on) Monitor.toggleSort()
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: Monitor.processes
                            Item {
                                id: procRow
                                required property var modelData
                                readonly property bool selected: root.selectedPid === modelData.pid
                                readonly property bool armed: selected && root.armedPid !== ""
                                readonly property real frac: Monitor.procSort === "mem" ? Math.min(1, modelData.mem / Math.max(1, Monitor.memTotal * 1024)) : Math.min(1, modelData.cpu / 100)
                                width: parent.width
                                height: parent.rowH

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height - 4
                                    width: parent.width
                                    radius: 4
                                    color: procRow.armed ? Qt.rgba(Main.theme.colRed.r, Main.theme.colRed.g, Main.theme.colRed.b, 0.2) : procRow.selected ? Main.theme.overlay(0.1) : rowMouse.containsMouse ? Main.theme.overlay(0.05) : "transparent"
                                    border.color: procRow.armed ? Main.theme.colRed : procRow.selected ? Main.theme.overlay(0.2) : "transparent"
                                    border.width: 1
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height - 4
                                    width: parent.width * parent.frac
                                    radius: 4
                                    color: Qt.rgba(Main.theme.colBlue.r, Main.theme.colBlue.g, Main.theme.colBlue.b, 0.14)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 400
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.selectedPid = procRow.selected ? "" : procRow.modelData.pid;
                                        root.armedPid = "";
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
                                    color: parent.modelData.cpu >= 100 ? Main.theme.colAmber : Main.theme.colFg
                                    font: Main.barFont
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
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
                    unavailable: root.focusing
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
                                    segments: [{ value: parent.modelData.used, color: root.heatColor(parent.modelData.used / Math.max(1, parent.modelData.total)) }]
                                }
                            }
                        }
                    }
                }

                Island {
                    width: (row3.width - layout.gap * 2) * 0.25
                    height: parent.height
                    title: "Sensors"
                    unavailable: root.focusing
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
                                        color: root.heatColor(parent.parent.heat)
                                    }
                                }
                                Text {
                                    id: tempText
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40
                                    horizontalAlignment: Text.AlignRight
                                    text: parent.modelData.temp + "°"
                                    color: parent.heat > 0.6 ? root.heatColor(parent.heat) : Main.theme.colFg
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
