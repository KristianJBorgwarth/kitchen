pragma Singleton

import QtQuick
import Quickshell
import qs.core
import qs.core.components
import qs.services
import "components"

// Timer / alarm, dropped down from the bar clock.
Scope {
    id: root
    readonly property alias opened: modal.opened

    function show() {
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

    Modal {
        id: modal
        fromTop: true
        edgeMargin: 34 + 8 // under the bar
        duration: 180
        maxWidth: 460
        maxHeight: content.implicitHeight + padding * 2
        padding: 28
        bindings: [
            { keys: "k", desc: "+1 min", run: () => Alarm.adjust(1) },
            { keys: "j", desc: "-1 min", run: () => Alarm.adjust(-1) },
            { keys: "K", desc: "+10 min", run: () => Alarm.adjust(10) },
            { keys: "J", desc: "-10 min", run: () => Alarm.adjust(-10) },
            { keys: "<Up>", desc: "", run: () => Alarm.adjust(1) },
            { keys: "<Down>", desc: "", run: () => Alarm.adjust(-1) },
            { keys: "h", desc: "timer", run: () => Alarm.setMode("timer") },
            { keys: "l", desc: "alarm", run: () => Alarm.setMode("alarm") },
            { keys: "<Tab>", desc: "switch timer / alarm", run: () => Alarm.setMode(Alarm.mode === "timer" ? "alarm" : "timer") },
            { keys: "<Space>", desc: "start / pause", run: () => Alarm.toggle() },
            { keys: "<CR>", desc: "", run: () => Alarm.toggle() },
            { keys: "r", desc: "reset", run: () => Alarm.reset() },
            { keys: "x", desc: "", run: () => Alarm.reset() }
        ]

        Column {
            id: content
            width: parent.width

            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 20
                    Repeater {
                        model: [
                            { id: "timer", name: "Timer" },
                            { id: "alarm", name: "Alarm" }
                        ]
                        Text {
                            id: tab
                            required property var modelData
                            readonly property bool current: Alarm.mode === modelData.id
                            text: modelData.name
                            color: current ? Main.theme.colFg : tabMouse.containsMouse && !Alarm.active ? Main.theme.colAccentMid : Main.theme.colAccentDark
                            font: Main.pillFont
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Alarm.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: Alarm.setMode(tab.modelData.id)
                            }
                        }
                    }
                }

                SectionLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Alarm.running ? "running" : Alarm.paused ? "paused" : "ready"
                    color: Alarm.running ? Main.theme.colFg : Main.theme.colAccentDark
                }
            }

            Item {
                width: 1
                height: 28
            }

            // the time; scroll or use the arrows to change it
            Item {
                width: parent.width
                height: 44

                IconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Alarm.active ? 0 : 1
                    enabled: !Alarm.active
                    icon: "󰍴"
                    tooltip: "Less (j)"
                    onClicked: Alarm.adjust(-1)
                }
                Text {
                    anchors.centerIn: parent
                    text: Alarm.mode === "alarm" && !Alarm.active ? Alarm.clock(Alarm.alarmAt) : Alarm.fmt(Alarm.remainingMs)
                    color: Alarm.paused ? Main.theme.colAccentMid : Main.theme.colFg
                    font: Main.displayFont
                }
                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Alarm.active ? 0 : 1
                    enabled: !Alarm.active
                    icon: "󰐕"
                    tooltip: "More (k)"
                    onClicked: Alarm.adjust(1)
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => Alarm.adjust(event.angleDelta.y > 0 ? 1 : -1)
                }
            }

            Item {
                width: 1
                height: 6
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const end = Qt.formatTime(new Date(Alarm.now + Alarm.remainingMs), "HH:mm");
                    if (Alarm.running)
                        return Alarm.mode === "alarm" ? "rings at " + end : "ends at " + end;
                    if (Alarm.paused)
                        return "of " + Alarm.fmt(Alarm.totalMs);
                    return Alarm.mode === "alarm" ? "in " + Alarm.fmt(Alarm.remainingMs) : "minutes";
                }
                color: Main.theme.colAccentMid
                font: Main.barFont
            }

            Item {
                width: 1
                height: 24
            }

            Rectangle {
                width: parent.width
                height: 2
                radius: 1
                color: Main.theme.overlay(0.08)
                Rectangle {
                    width: parent.width * Alarm.progress
                    height: parent.height
                    radius: 1
                    color: Alarm.running ? Main.theme.colFg : Main.theme.colAccentMid
                    Behavior on width {
                        enabled: Alarm.running
                        NumberAnimation {
                            duration: 1000
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 24
            }

            // presets for the timer
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 24
                spacing: 22
                opacity: Alarm.mode === "timer" && !Alarm.active ? 1 : 0
                enabled: opacity > 0
                Repeater {
                    model: [5, 10, 15, 30, 60]
                    Text {
                        id: preset
                        required property int modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData + "m"
                        color: Alarm.minutes === modelData ? Main.theme.colFg : presetMouse.containsMouse ? Main.theme.colAccentMid : Main.theme.colAccentDark
                        font: Main.barFont
                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Alarm.setMinutes(preset.modelData)
                        }
                    }
                }
            }

            Item {
                width: 1
                height: 20
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 120
                    height: 36
                    radius: Main.radius
                    color: Main.theme.overlay(playMouse.containsMouse ? 0.12 : 0.07)
                    Text {
                        anchors.centerIn: parent
                        text: Alarm.running ? (Alarm.mode === "alarm" ? "Cancel" : "Pause") : Alarm.paused ? "Resume" : "Start"
                        color: Main.theme.colFg
                        font: Main.barFont
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Alarm.toggle()
                    }
                }
                IconButton {
                    visible: Alarm.active
                    icon: "󰑙"
                    tooltip: "Reset (r)"
                    onClicked: Alarm.reset()
                }
            }

            Item {
                width: 1
                height: 20
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "j k adjust   space start   ? keys"
                color: Main.theme.colAccentDark
                font: Main.smallFont
            }
        }
    }
}
