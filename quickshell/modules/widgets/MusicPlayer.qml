pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

Scope {
    id: root
    readonly property alias opened: modal.opened
    property bool showRemaining: false

    property MprisPlayer selected: null
    readonly property var players: Media.players
    readonly property MprisPlayer player: players.includes(selected) ? selected : Media.player
    readonly property bool playing: player?.isPlaying ?? false
    // browsers only give a ~150px thumbnail; a generic cover beats a blurry one
    readonly property bool genericArt: Media.isBrowser(player)
    readonly property string artUrl: genericArt ? "" : (player?.trackArtUrl ?? "")

    onPlayerChanged: if (!player && opened) hide()

    readonly property string lyricsKey: opened ? [player?.trackArtist, player?.trackTitle, Lyrics.enabled].join("|") : ""
    onLyricsKeyChanged: {
        if (opened && player)
            Lyrics.load(player.trackTitle ?? "", player.trackArtist ?? "", player.trackAlbum ?? "", player.length ?? 0);
    }

    function show() {
        if (player)
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

    function fmt(secs) {
        if (!isFinite(secs) || secs < 0)
            secs = 0;
        const s = Math.floor(secs);
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
    }

    function seekBy(secs) {
        if (player?.canSeek)
            player.position = Math.max(0, Math.min(player.length, player.position + secs));
    }

    property real volumeBeforeMute: 0.5

    function toggleMute() {
        if (!player?.volumeSupported)
            return;
        if (player.volume > 0) {
            volumeBeforeMute = player.volume;
            player.volume = 0;
        } else {
            player.volume = volumeBeforeMute;
        }
    }

    function cyclePlayer(step) {
        if (players.length < 2)
            return;
        selected = players[(players.indexOf(player) + step + players.length) % players.length];
    }

    function cycleLoop() {
        if (!player?.loopSupported)
            return;
        const s = player.loopState;
        player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    function volumeBy(d) {
        if (player?.volumeSupported)
            player.volume = Math.max(0, Math.min(1, player.volume + d));
    }

    // MPRIS doesn't push position updates; poke it often enough for synced lyrics
    Timer {
        interval: 250
        running: root.opened && root.playing
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Modal {
        id: modal
        framed: true
        maxWidth: 1100
        maxHeight: 680
        padding: Main.pad

        actions: [
            Repeater {
                model: root.players.length > 1 ? root.players : []
                Chip {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.isPlaying ? "󰐊  " : "󰏤  ") + modelData.identity
                    active: modelData === root.player
                    clickable: true
                    onClicked: root.selected = modelData
                }
            },
            // opt-in: it sends artist/title to lrclib.net
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰎈  Lyrics"
                active: Lyrics.enabled
                clickable: true
                onClicked: Lyrics.setEnabled(!Lyrics.enabled)
            },
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 28
                implicitHeight: 28
                visible: root.player?.canRaise ?? false
                icon: "󰏌"
                onClicked: {
                    root.player.raise();
                    root.hide();
                }
            }
        ]
        bindings: [
            { keys: "<Space>", desc: "play / pause", run: () => root.player?.togglePlaying() },
            { keys: "h", desc: "previous track", run: () => root.player?.previous() },
            { keys: "l", desc: "next track", run: () => root.player?.next() },
            { keys: "H", desc: "seek back 10s", run: () => root.seekBy(-10) },
            { keys: "L", desc: "seek forward 10s", run: () => root.seekBy(10) },
            { keys: "<Left>", desc: "", run: () => root.seekBy(-5) },
            { keys: "<Right>", desc: "", run: () => root.seekBy(5) },
            { keys: "0", desc: "back to start", run: () => root.seekBy(-1e9) },
            { keys: "gg", desc: "", run: () => root.seekBy(-1e9) },
            { keys: "k", desc: "volume up", run: () => root.volumeBy(0.05) },
            { keys: "j", desc: "volume down", run: () => root.volumeBy(-0.05) },
            { keys: "<Up>", desc: "", run: () => root.volumeBy(0.05) },
            { keys: "<Down>", desc: "", run: () => root.volumeBy(-0.05) },
            { keys: "m", desc: "mute", run: () => root.toggleMute() },
            { keys: "s", desc: "shuffle", run: () => { if (root.player?.shuffleSupported) root.player.shuffle = !root.player.shuffle; } },
            { keys: "r", desc: "repeat mode", run: () => root.cycleLoop() },
            { keys: "t", desc: "lyrics", run: () => Lyrics.setEnabled(!Lyrics.enabled) },
            { keys: "gt", desc: "next player", run: () => root.cyclePlayer(1) },
            { keys: "gT", desc: "previous player", run: () => root.cyclePlayer(-1) },
            { keys: "o", desc: "open app", run: () => { if (root.player?.canRaise) { root.player.raise(); root.hide(); } } }
        ]

        // blurred cover wash over the whole card. The blur runs on a 1/8-size copy that
        // is scaled up: same look, a fraction of the GPU work (matters on laptop iGPUs)
        background: Item {
            anchors.fill: parent

            Item {
                width: parent.width / 8
                height: parent.height / 8
                scale: 8
                transformOrigin: Item.TopLeft
                layer.enabled: true
                layer.smooth: true

                Image {
                    id: wash
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 64
                    sourceSize.height: 64
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: wash
                    visible: wash.status === Image.Ready
                    opacity: 0.45
                    blurEnabled: true
                    blur: 1
                    blurMax: 8
                    saturation: -0.3
                    brightness: -0.2
                }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(Main.theme.colBg.r, Main.theme.colBg.g, Main.theme.colBg.b, 0.35)
                    }
                    GradientStop {
                        position: 0.75
                        color: Main.theme.colBg
                    }
                }
            }
        }

        Item {
            id: layout
            anchors.fill: parent

            Item {
                id: main
                anchors.top: parent.top
                anchors.bottom: spectrum.top
                anchors.bottomMargin: 20
                width: parent.width

                readonly property real coverSize: Math.min(height, 380)

                ClippingRectangle {
                    id: cover
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: main.coverSize
                    height: main.coverSize
                    radius: Main.radius
                    color: Main.theme.colSurface

                    Rectangle {
                        anchors.fill: parent
                        visible: coverImg.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Main.theme.colMuted
                            }
                            GradientStop {
                                position: 1
                                color: Main.theme.colSurface
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰎈"
                                color: Main.theme.colAccentLight
                                font: Main.heroFont
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.player?.identity ?? ""
                                color: Main.theme.colAccentMid
                                font: Main.barFont
                            }
                        }
                    }
                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 760
                        sourceSize.height: 760
                    }
                }

                Item {
                    id: info
                    anchors.left: parent.left
                    anchors.leftMargin: main.coverSize + 40
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Column {
                        id: titleBlock
                        width: parent.width
                        spacing: 6

                        Text {
                            width: parent.width
                            text: root.player?.trackTitle || root.player?.identity || ""
                            color: Main.theme.colFg
                            font: Main.displayFont
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: root.player?.trackArtist ?? ""
                            color: Main.theme.colAccentLight
                            font.family: Main.fontFamily
                            font.pixelSize: Main.titleFont.pixelSize
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: root.player?.trackAlbum ?? ""
                            color: Main.theme.colAccentMid
                            font: Main.barFont
                            elide: Text.ElideRight
                        }

                        Flow {
                            width: parent.width
                            spacing: 6
                            topPadding: 4
                            Repeater {
                                model: {
                                    const md = root.player?.metadata ?? {};
                                    // genre arrives as a list, which can stringify to "Pop,Rock"
                                    const chips = String(md["xesam:genre"] ?? "").split(",").map(g => g.trim()).filter(g => g).slice(0, 3);
                                    if (md["xesam:trackNumber"])
                                        chips.push("#" + md["xesam:trackNumber"]);
                                    return chips;
                                }
                                Chip {
                                    required property var modelData
                                    implicitHeight: 22
                                    text: String(modelData)
                                }
                            }
                        }
                    }

                    Item {
                        id: lyricsBox
                        anchors.top: titleBlock.bottom
                        anchors.topMargin: 16
                        anchors.bottom: controls.top
                        anchors.bottomMargin: 16
                        width: parent.width
                        clip: true

                        readonly property int current: {
                            if (Lyrics.status !== "synced")
                                return -1;
                            const pos = (root.player?.position ?? 0) + 0.3;
                            let i = -1;
                            for (let j = 0; j < Lyrics.lines.length && Lyrics.lines[j].time <= pos; j++)
                                i = j;
                            return i;
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Lyrics.status !== "synced" && Lyrics.status !== "plain"
                            text: ({
                                    off: "Press t or the Lyrics button for synced lyrics",
                                    loading: "Looking up lyrics…",
                                    none: "No lyrics found for this track"
                                })[Lyrics.status] ?? ""
                            color: Main.theme.colAccentDark
                            font: Main.barFont
                        }

                        ListView {
                            id: lyricsView
                            anchors.fill: parent
                            visible: Lyrics.status === "synced" || Lyrics.status === "plain"
                            model: Lyrics.lines
                            interactive: Lyrics.status === "plain"
                            currentIndex: Math.max(0, lyricsBox.current)
                            highlightRangeMode: Lyrics.status === "synced" ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                            preferredHighlightBegin: height / 2 - 14
                            preferredHighlightEnd: height / 2 + 14
                            highlightMoveDuration: Main.anim * 2
                            spacing: 4

                            delegate: Text {
                                required property var modelData
                                required property int index
                                readonly property bool active: index === lyricsBox.current
                                width: lyricsView.width
                                text: modelData.text || "♪"
                                color: active || Lyrics.status === "plain" ? Main.theme.colFg : Main.theme.colAccentDark
                                font.family: Main.fontFamily
                                font.pixelSize: active ? 18 : 15
                                font.weight: active ? Font.DemiBold : Font.Normal
                                wrapMode: Text.Wrap

                                Behavior on font.pixelSize {
                                    NumberAnimation {
                                        duration: Main.anim
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        id: controls
                        anchors.bottom: parent.bottom
                        width: parent.width
                        spacing: 14

                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.player?.lengthSupported ?? false

                            Item {
                                id: seek
                                width: parent.width
                                height: 16
                                readonly property real len: root.player?.length ?? 0
                                readonly property real frac: seekMouse.pressed ? seekMouse.dragFrac : (len > 0 ? Math.max(0, Math.min(1, (root.player?.position ?? 0) / len)) : 0)

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: seekMouse.containsMouse ? 6 : 4
                                    radius: height / 2
                                    color: Main.theme.overlay(0.12)

                                    Behavior on height {
                                        NumberAnimation {
                                            duration: Main.anim
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width * seek.frac
                                        height: parent.height
                                        radius: parent.radius
                                        color: Main.theme.colFg
                                    }
                                }

                                Rectangle {
                                    visible: root.player?.canSeek ?? false
                                    x: seek.width * seek.frac - width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: seekMouse.containsMouse || seekMouse.pressed ? 14 : 0
                                    height: width
                                    radius: width / 2
                                    color: Main.theme.colFg

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Main.anim
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: seekMouse.containsMouse && seek.len > 0
                                    x: Math.max(0, Math.min(seek.width - width, seekMouse.mouseX - width / 2))
                                    y: -height - 6
                                    width: hoverTime.implicitWidth + 12
                                    height: 20
                                    radius: Main.radius
                                    color: Main.theme.colFg
                                    Text {
                                        id: hoverTime
                                        anchors.centerIn: parent
                                        text: root.fmt(seek.len * Math.max(0, Math.min(1, seekMouse.mouseX / seek.width)))
                                        color: Main.theme.colBg
                                        font: Main.smallFont
                                    }
                                }

                                MouseArea {
                                    id: seekMouse
                                    anchors.fill: parent
                                    enabled: root.player?.canSeek ?? false
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    property real dragFrac: 0
                                    onPressed: mouse => dragFrac = Math.max(0, Math.min(1, mouse.x / seek.width))
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            dragFrac = Math.max(0, Math.min(1, mouse.x / seek.width));
                                    }
                                    onReleased: root.player.position = seek.len * dragFrac
                                }
                            }

                            Item {
                                width: parent.width
                                height: elapsed.implicitHeight
                                Text {
                                    id: elapsed
                                    text: root.fmt(seek.len * seek.frac)
                                    color: Main.theme.colAccentMid
                                    font: Main.smallFont
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: root.showRemaining ? "-" + root.fmt(seek.len * (1 - seek.frac)) : root.fmt(seek.len)
                                    color: Main.theme.colAccentMid
                                    font: Main.smallFont
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showRemaining = !root.showRemaining
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 60

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.player?.shuffleSupported ?? false
                                    icon: "󰒝"
                                    opacity: root.player?.shuffle ? 1 : 0.4
                                    onClicked: root.player.shuffle = !root.player.shuffle
                                }
                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: 44
                                    implicitHeight: 44
                                    radius: Main.radius
                                    icon: "󰒮"
                                    opacity: root.player?.canGoPrevious ? 1 : 0.4
                                    onClicked: root.player?.previous()
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 60
                                    height: 60
                                    radius: Main.radius
                                    color: playMouse.containsMouse ? Main.theme.colAccentLight : Main.theme.colFg
                                    scale: playMouse.pressed ? 0.92 : 1

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Main.anim
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Main.anim
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.playing ? "󰏤" : "󰐊"
                                        color: Main.theme.colBg
                                        font: Main.displayFont
                                    }
                                    MouseArea {
                                        id: playMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.player?.togglePlaying()
                                    }
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: 44
                                    implicitHeight: 44
                                    radius: Main.radius
                                    icon: "󰒭"
                                    opacity: root.player?.canGoNext ? 1 : 0.4
                                    onClicked: root.player?.next()
                                }
                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.player?.loopSupported ?? false
                                    icon: root.player?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                                    opacity: root.player?.loopState === MprisLoopState.None ? 0.4 : 1
                                    onClicked: root.cycleLoop()
                                }
                            }

                            SliderRow {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(200, parent.width - 330)
                                visible: (root.player?.volumeSupported ?? false) && width > 90
                                icon: (root.player?.volume ?? 0) === 0 ? "󰝟" : "󰕾"
                                value: root.player?.volume ?? 0
                                onMoved: v => root.player.volume = v
                                onIconClicked: root.player.volume = root.player.volume > 0 ? 0 : 0.5
                            }
                        }
                    }
                }
            }

            Spectrum {
                id: spectrum
                anchors.bottom: parent.bottom
                width: parent.width
                height: 110
                playing: root.opened && root.playing
            }
        }
    }
}
