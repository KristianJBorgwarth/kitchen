pragma Singleton

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.core
import qs.core.components
import qs.services
import "components"

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

    property color phaseColor: Pomodoro.phase === "focus" ? Main.theme.colRed : Pomodoro.phase === "short" ? Main.theme.colGreen : Main.theme.colBlue
    Behavior on phaseColor {
        ColorAnimation {
            duration: 150
        }
    }
    readonly property var phases: [
        { id: "focus", name: "Focus" },
        { id: "short", name: "Short break" },
        { id: "long", name: "Long break" }
    ]

    Modal {
        id: modal
        maxWidth: 440
        maxHeight: 880
        padding: 24
        bindings: [
            { keys: "<Space>", desc: "start / pause", run: () => Pomodoro.toggle() },
            { keys: "s", desc: "skip phase", run: () => Pomodoro.skip() },
            { keys: "r", desc: "reset", run: () => Pomodoro.reset() },
            { keys: "1", desc: "focus", run: () => Pomodoro.setPhase("focus") },
            { keys: "2", desc: "short break", run: () => Pomodoro.setPhase("short") },
            { keys: "3", desc: "long break", run: () => Pomodoro.setPhase("long") },
            { keys: "i", desc: "edit task label", run: () => label.forceActiveFocus() },
            { keys: "<Esc>", desc: "", run: () => root.hide() }
        ]

        Column {
            anchors.fill: parent
            spacing: 18

            // phase selector
            Rectangle {
                width: parent.width
                height: 34
                radius: Main.radius
                color: Main.theme.colSurface
                border.color: Main.theme.overlay(0.05)
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    Repeater {
                        model: root.phases
                        Rectangle {
                            id: seg
                            required property var modelData
                            readonly property bool current: Pomodoro.phase === modelData.id
                            width: parent.width / 3
                            height: parent.height
                            radius: Main.radius - 1
                            color: current ? Qt.rgba(root.phaseColor.r, root.phaseColor.g, root.phaseColor.b, 0.16) : segMouse.containsMouse ? Main.theme.overlay(0.05) : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Main.anim
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: seg.modelData.name + (!seg.current && Pomodoro.hasProgress(seg.modelData.id) ? "  ●" : "")
                                color: seg.current ? root.phaseColor : Main.theme.colAccentLight
                                font: Main.barFont
                            }
                            MouseArea {
                                id: segMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pomodoro.setPhase(seg.modelData.id)
                            }
                        }
                    }
                }
            }

            // timer
            Item {
                id: ringBox
                anchors.horizontalCenter: parent.horizontalCenter
                width: 230
                height: 230

                // eases between the once-a-second updates while running; snaps otherwise
                property real p: Pomodoro.progress
                Behavior on p {
                    enabled: Pomodoro.running
                    NumberAnimation {
                        duration: 1000
                    }
                }
                readonly property real r: width / 2 - 4

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    layer.enabled: true
                    layer.samples: 4

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Main.theme.overlay(0.07)
                        strokeWidth: 4
                        PathAngleArc {
                            centerX: ringBox.width / 2
                            centerY: ringBox.height / 2
                            radiusX: ringBox.r
                            radiusY: radiusX
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root.phaseColor
                        strokeWidth: 4
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: ringBox.width / 2
                            centerY: ringBox.height / 2
                            radiusX: ringBox.r
                            radiusY: radiusX
                            startAngle: -90
                            sweepAngle: Math.max(0.01, 360 * ringBox.p)
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    SectionLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Pomodoro.running ? "running" : Pomodoro.paused ? "paused" : "ready"
                        color: Pomodoro.running ? root.phaseColor : Main.theme.colAccentMid
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Pomodoro.fmt(Pomodoro.remainingMs)
                        color: Main.theme.colFg
                        font.family: Main.fontFamily
                        font.pixelSize: 54
                        font.weight: Font.Light
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        Repeater {
                            model: Pomodoro.sessionsBeforeLong
                            Rectangle {
                                required property int index
                                width: 14
                                height: 3
                                radius: 1
                                color: index < Pomodoro.cycle ? root.phaseColor : Main.theme.overlay(0.12)
                            }
                        }
                    }
                }
            }

            // controls
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "󰑙"
                    tooltip: "Reset (r)"
                    onClicked: Pomodoro.reset()
                }
                Rectangle {
                    width: 56
                    height: 56
                    radius: Main.radius * 2
                    color: playMouse.containsMouse ? Qt.lighter(root.phaseColor, 1.1) : root.phaseColor
                    Text {
                        anchors.centerIn: parent
                        text: Pomodoro.running ? "󰏤" : "󰐊"
                        color: Main.theme.colBg
                        font.family: Main.fontFamily
                        font.pixelSize: 26
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pomodoro.toggle()
                    }
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "󰒭"
                    tooltip: "Skip (s)"
                    onClicked: Pomodoro.skip()
                }
            }

            // what you're working on
            Rectangle {
                width: parent.width
                height: 34
                radius: Main.radius
                color: Main.theme.colSurface
                border.color: label.activeFocus ? Main.theme.colAccentMid : Main.theme.overlay(0.05)
                border.width: 1

                TextInput {
                    id: label
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    text: Pomodoro.label
                    onTextEdited: Pomodoro.setLabel(text)
                    color: Main.theme.colFg
                    font: Main.barFont
                    clip: true
                    Keys.onEscapePressed: modal.body.forceActiveFocus()
                    Keys.onReturnPressed: modal.body.forceActiveFocus()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !label.text && !label.activeFocus
                        text: "What are you working on?"
                        color: Main.theme.colAccentDark
                        font: Main.barFont
                    }
                }
            }

            Island {
                width: parent.width
                height: 158
                title: "Today"

                Column {
                    anchors.fill: parent
                    spacing: 14

                    Row {
                        width: parent.width
                        Repeater {
                            model: [
                                { value: Pomodoro.today.count + " / " + Pomodoro.dailyGoal, name: "sessions" },
                                { value: Pomodoro.today.minutes + "m", name: "focused" },
                                { value: String(Pomodoro.streak), name: Pomodoro.streak === 1 ? "day streak" : "day streak" }
                            ]
                            Column {
                                required property var modelData
                                width: parent.width / 3
                                spacing: 2
                                Text {
                                    text: modelData.value
                                    color: Main.theme.colFg
                                    font.family: Main.fontFamily
                                    font.pixelSize: 20
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: modelData.name
                                    color: Main.theme.colAccentMid
                                    font: Main.smallFont
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 50
                        spacing: 8
                        Repeater {
                            model: Pomodoro.week
                            Item {
                                id: bar
                                required property var modelData
                                width: (parent.width - 6 * 8) / 7
                                height: parent.height
                                readonly property real frac: Math.min(1, modelData.count / Math.max(1, Pomodoro.dailyGoal))
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: dayText.top
                                    anchors.bottomMargin: 5
                                    width: parent.width
                                    height: 3 + (parent.height - 24) * bar.frac
                                    radius: 1
                                    color: bar.modelData.count === 0 ? Main.theme.overlay(0.08) : bar.modelData.today ? root.phaseColor : Main.theme.colAccentMid
                                }
                                Text {
                                    id: dayText
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: bar.modelData.day
                                    color: bar.modelData.today ? Main.theme.colFg : Main.theme.colAccentDark
                                    font: Main.smallFont
                                }
                            }
                        }
                    }
                }
            }

            Island {
                width: parent.width
                height: 150
                title: "Recent"

                // the first click arms it, a second within 3s clears
                Text {
                    id: clearBtn
                    property bool armed: false
                    visible: Pomodoro.history.length > 0
                    x: parent.width - width
                    y: -33
                    text: armed ? "Click again to clear" : "Clear"
                    color: armed ? Main.theme.colRed : clearMouse.containsMouse ? Main.theme.colFg : Main.theme.colAccentDark
                    font: Main.smallFont
                    Timer {
                        id: disarm
                        interval: 3000
                        onTriggered: clearBtn.armed = false
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (clearBtn.armed) {
                                clearBtn.armed = false;
                                Pomodoro.clearHistory();
                            } else {
                                clearBtn.armed = true;
                                disarm.restart();
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Pomodoro.history.length === 0
                    text: "No sessions yet"
                    color: Main.theme.colAccentDark
                    font: Main.barFont
                }

                ListView {
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Pomodoro.history.slice(-30).reverse()
                    delegate: Item {
                        id: entry
                        required property var modelData
                        width: ListView.view.width
                        height: 28

                        HoverHandler {
                            id: rowHover
                        }

                        Text {
                            id: when
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(new Date(entry.modelData.start), "ddd HH:mm")
                            color: Main.theme.colAccentMid
                            font: Main.smallFont
                        }
                        Text {
                            anchors.left: when.right
                            anchors.leftMargin: 14
                            anchors.right: mins.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.label || "Untitled"
                            color: entry.modelData.label ? Main.theme.colFg : Main.theme.colAccentDark
                            font: Main.barFont
                            elide: Text.ElideRight
                        }
                        Text {
                            id: mins
                            anchors.right: del.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.minutes + "m" + (entry.modelData.completed ? "" : " · stopped")
                            color: entry.modelData.completed ? Main.theme.colAccentLight : Main.theme.colAmber
                            font: Main.smallFont
                        }
                        Text {
                            id: del
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignRight
                            text: "󰅖"
                            font: Main.barFont
                            opacity: rowHover.hovered ? 1 : 0
                            color: delMouse.containsMouse ? Main.theme.colRed : Main.theme.colAccentMid
                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                anchors.margins: -5
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pomodoro.removeEntry(entry.modelData)
                            }
                        }
                    }
                }
            }

            // settings
            Row {
                width: parent.width
                height: 28
                spacing: 20

                Repeater {
                    model: [
                        { key: "autoStart", name: "Auto-start" },
                        { key: "sound", name: "Sound" }
                    ]
                    Row {
                        id: opt
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Switch {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 34
                            implicitHeight: 18
                            accent: root.phaseColor
                            checked: Pomodoro[opt.modelData.key]
                            onToggled: Pomodoro.setSetting(opt.modelData.key, !Pomodoro[opt.modelData.key])
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: opt.modelData.name
                            color: Main.theme.colAccentLight
                            font: Main.smallFont
                        }
                    }
                }

                Item {
                    width: 1
                    height: 1
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Pomodoro.focusMin + " / " + Pomodoro.shortMin + " / " + Pomodoro.longMin + " min"
                    clickable: true
                    onClicked: {
                        const presets = [[25, 5, 15], [50, 10, 30], [45, 15, 30], [15, 3, 10]];
                        const i = presets.findIndex(p => p[0] === Pomodoro.focusMin && p[1] === Pomodoro.shortMin && p[2] === Pomodoro.longMin);
                        const n = presets[(i + 1) % presets.length];
                        Pomodoro.setSetting("focusMin", n[0]);
                        Pomodoro.setSetting("shortMin", n[1]);
                        Pomodoro.setSetting("longMin", n[2]);
                    }
                }
            }
        }
    }
}
