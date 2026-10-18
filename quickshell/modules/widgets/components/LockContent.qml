import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower as QsPower
import qs.core
import qs.core.themes
import qs.core.components
import qs.services

// What a lock surface shows: blurred wallpaper, clock and date, password box. The
// password and status live in `lock` (the Lock singleton), shared by every monitor.
Item {
    id: root
    required property var lock
    // false on the other monitors: wallpaper only, though typing still reaches the password
    property bool main: true
    // preview: same look, but Enter just closes it instead of checking a password
    property bool preview: false
    signal closePreview

    // the lock screen sits on a darkened wallpaper, so it keeps the dark palette in light mode
    Theme {
        id: dark
        fixed: "dark"
    }

    function submit() {
        if (preview)
            closePreview();
        else
            root.lock.tryUnlock();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string wallpaper: Wallpaper.url

    Rectangle {
        anchors.fill: parent
        color: dark.colBg
    }

    // blurred on a 1/8-size copy, then scaled up: same look for a fraction of the work
    Item {
        width: parent.width / 8
        height: parent.height / 8
        scale: 8
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: true

        Image {
            id: wall
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 480
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            visible: wall.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 12
            brightness: -0.25
            saturation: -0.2
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.25)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.6)
            }
        }
    }

    // clicks anywhere hand focus back to the password box
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    Column {
        visible: root.main
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.08
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            color: dark.colFg
            font.family: Main.fontFamily
            font.pixelSize: 132
            font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: dark.colAccentLight
            font.family: Main.fontFamily
            font.pixelSize: 22
        }
    }

    // password box (invisible but still focused on the other monitors)
    Column {
        opacity: root.main ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: parent.height * 0.12
        spacing: 12

        Rectangle {
            id: box
            width: 340
            height: 48
            radius: Main.radius
            color: Qt.rgba(0, 0, 0, 0.45)
            border.color: root.lock.failed ? dark.colRed : input.activeFocus ? dark.colAccentMid : dark.overlay(0.12)
            border.width: 1

            // shake on a wrong password
            transform: Translate {
                id: shakeOffset
            }
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: shakeOffset; property: "x"; to: -10; duration: 40 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 10; duration: 80 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 40 }
            }
            Connections {
                target: root.lock
                function onFailedChanged() {
                    if (root.lock.failed)
                        shake.restart();
                }
            }

            Text {
                id: lockIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.lock.busy ? "󰔟" : "󰌾"
                color: root.lock.failed ? dark.colRed : dark.colAccentMid
                font: Main.barFont
            }

            // the real input stays invisible; the dots below stand in for it
            TextInput {
                id: input
                anchors.fill: parent
                opacity: 0
                focus: true
                echoMode: TextInput.Password
                text: root.lock.password
                onTextEdited: root.lock.password = text
                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
                Keys.onEscapePressed: root.preview ? root.closePreview() : root.lock.password = ""
                Component.onCompleted: forceActiveFocus()
            }

            Row {
                anchors.left: lockIcon.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                clip: true

                Text {
                    visible: root.lock.password.length === 0
                    text: root.lock.busy ? "Checking…" : "Type your password"
                    color: dark.colAccentDark
                    font: Main.barFont
                }
                Repeater {
                    model: Math.min(root.lock.password.length, 24)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: dark.colFg
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lock.failed ? "Wrong password" : root.lock.message
            visible: text !== ""
            color: root.lock.failed ? dark.colRed : dark.colAccentMid
            font: Main.smallFont
        }
    }

    // bottom bar: who, battery, now playing
    Item {
        visible: root.main
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        height: 32

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰀄  " + Session.user + "@" + Session.host
            color: dark.colAccentLight
            font: Main.barFont
        }

        Chip {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.player !== null
            implicitHeight: 30
            padding: 14
            maxWidth: 420
            font: Main.barFont
            text: (Media.player?.isPlaying ? "󰏤  " : "󰐊  ") + (Media.player?.trackTitle ?? "") + (Media.player?.trackArtist ? "  ·  " + Media.player.trackArtist : "")
            clickable: true
            onClicked: Media.player?.togglePlaying()
        }

        Text {
            readonly property var battery: QsPower.UPower.displayDevice
            readonly property real level: (battery?.percentage ?? 0) > 1 ? battery.percentage / 100 : (battery?.percentage ?? 0)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: battery?.isLaptopBattery ?? false
            text: "󰁹  " + Math.round(level * 100) + "%"
            color: level < 0.15 ? dark.colRed : dark.colAccentLight
            font: Main.barFont
        }
    }
}
