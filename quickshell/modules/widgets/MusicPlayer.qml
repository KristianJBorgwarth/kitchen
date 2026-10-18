pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.core
import qs.services
import "components"

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    anchors.top: true
    anchors.left: true
    exclusiveZone: 0

    implicitWidth: 360
    implicitHeight: content.implicitHeight + 32

    // x center of the bar's music island, set by Bar.qml
    property real anchorX: 0

    margins {
        top: 4
        left: Math.max(6, root.anchorX - root.implicitWidth / 2)
    }

    property bool opened: false

    // user-picked player; falls back to Media.player when unset or gone
    property MprisPlayer selected: null
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.includes(selected) ? selected : Media.player

    onPlayerChanged: if (!player && opened) hide()

    function show() {
        if (!player)
            return;
        if (ControlCenter.opened)
            ControlCenter.hide();
        if (TrayPanel.opened)
            TrayPanel.hide();
        unmapTimer.stop();
        root.visible = true;
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

    function cyclePlayer() {
        if (players.length < 2)
            return;
        selected = players[(players.indexOf(player) + 1) % players.length];
    }

    function fmt(secs) {
        if (!isFinite(secs) || secs < 0)
            secs = 0;
        const s = Math.floor(secs);
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
    }

    Timer {
        id: unmapTimer
        interval: 220
        onTriggered: {
            if (!root.opened)
                root.visible = false;
        }
    }

    // MPRIS doesn't push position updates; poke it while playing
    Timer {
        interval: 1000
        running: root.opened && (root.player?.isPlaying ?? false)
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Rectangle {
        id: blob
        anchors.fill: parent
        radius: 4
        color: Main.theme.colBg
        border.color: Main.theme.colMuted
        border.width: 1

        transformOrigin: Item.Top
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
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 12

            // player switcher
            Item {
                width: parent.width
                height: 20
                visible: root.players.length > 1

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30
                    text: (root.player?.identity ?? "") + "  " + (root.players.indexOf(root.player) + 1) + "/" + root.players.length
                    color: Main.theme.colAccentMid
                    font: Main.smallFont
                    elide: Text.ElideRight
                }
                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 24
                    implicitHeight: 20
                    icon: "󰒭"
                    iconFont: Main.barFont
                    onClicked: root.cyclePlayer()
                }
            }

            ClippingRectangle {
                id: art
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: width
                radius: 4
                color: Main.theme.colSurface

                Text {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "󰎈"
                    color: Main.theme.colMuted
                    font.family: Main.fontFamily
                    font.pixelSize: 96
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 512
                    sourceSize.height: 512
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: root.player?.trackTitle || root.player?.identity || ""
                    color: Main.theme.colFg
                    font.family: Main.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.player?.trackArtist ?? ""
                    color: Main.theme.colAccentLight
                    font: Main.barFont
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.player?.trackAlbum ?? ""
                    color: Main.theme.colAccentMid
                    font: Main.smallFont
                    elide: Text.ElideRight
                }
            }

            // seek bar
            Column {
                width: parent.width
                spacing: 4
                visible: root.player?.lengthSupported ?? false

                Item {
                    id: seek
                    width: parent.width
                    height: 14
                    readonly property real len: root.player?.length ?? 0
                    readonly property real frac: len > 0 ? Math.max(0, Math.min(1, (root.player?.position ?? 0) / len)) : 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Main.theme.colMuted

                        Rectangle {
                            width: parent.width * seek.frac
                            height: parent.height
                            radius: 2
                            color: Main.theme.colAccentLight
                        }
                    }

                    Rectangle {
                        visible: root.player?.canSeek ?? false
                        x: seek.width * seek.frac - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: seekMouse.containsMouse ? 12 : 8
                        height: width
                        radius: width / 2
                        color: Main.theme.colFg
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        enabled: root.player?.canSeek ?? false
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            root.player.position = seek.len * Math.max(0, Math.min(1, mouse.x / seek.width));
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: elapsed.implicitHeight
                    Text {
                        id: elapsed
                        anchors.left: parent.left
                        text: root.fmt(root.player?.position ?? 0)
                        color: Main.theme.colAccentMid
                        font: Main.smallFont
                    }
                    Text {
                        anchors.right: parent.right
                        text: root.fmt(seek.len)
                        color: Main.theme.colAccentMid
                        font: Main.smallFont
                    }
                }
            }

            // controls
            Item {
                width: parent.width
                height: 40

                IconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.player?.shuffleSupported ?? false
                    icon: "󰒝"
                    opacity: root.player?.shuffle ? 1 : 0.4
                    onClicked: root.player.shuffle = !root.player.shuffle
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    IconButton {
                        icon: "󰒮"
                        opacity: root.player?.canGoPrevious ? 1 : 0.4
                        onClicked: root.player?.previous()
                    }
                    IconButton {
                        implicitWidth: 44
                        implicitHeight: 40
                        border.color: Main.theme.colMuted
                        border.width: 1
                        icon: root.player?.isPlaying ? "󰏤" : "󰐊"
                        onClicked: root.player?.togglePlaying()
                    }
                    IconButton {
                        icon: "󰒭"
                        opacity: root.player?.canGoNext ? 1 : 0.4
                        onClicked: root.player?.next()
                    }
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.player?.loopSupported ?? false
                    icon: root.player?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                    opacity: root.player?.loopState === MprisLoopState.None ? 0.4 : 1
                    onClicked: {
                        const s = root.player.loopState;
                        root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                    }
                }
            }
        }
    }
}
