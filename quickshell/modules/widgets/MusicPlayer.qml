pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.I3
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

// Full music player: a centered card over a dimmed screen, like SystemMonitor.
// Vim-style keys while open (? shows them all): h/l prev/next, H/L seek, j/k volume, …
Scope {
    id: root
    property bool opened: false
    property bool showRemaining: false

    // user-picked player; falls back to Media.player when unset or gone
    property MprisPlayer selected: null
    readonly property var players: Media.players
    readonly property MprisPlayer player: players.includes(selected) ? selected : Media.player
    readonly property bool playing: player?.isPlaying ?? false
    // browsers only give a ~150px thumbnail; a generic cover beats a blurry one
    readonly property bool genericArt: Media.isBrowser(player)
    readonly property string artUrl: genericArt ? "" : (player?.trackArtUrl ?? "")

    onPlayerChanged: if (!player && opened) hide()

    // fetch lyrics only while the window is open
    readonly property string lyricsKey: opened ? [player?.trackArtist, player?.trackTitle, Lyrics.enabled].join("|") : ""
    onLyricsKeyChanged: {
        if (opened && player)
            Lyrics.load(player.trackTitle ?? "", player.trackArtist ?? "", player.trackAlbum ?? "", player.length ?? 0);
    }

    function show() {
        if (!player)
            return;
        if (ControlCenter.opened)
            ControlCenter.hide();
        if (TrayPanel.opened)
            TrayPanel.hide();
        unmapTimer.stop();
        const focused = Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name);
        if (focused)
            win.screen = focused;
        win.visible = true;
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

    Timer {
        id: unmapTimer
        interval: Main.anim + 20
        onTriggered: {
            if (!root.opened)
                win.visible = false;
        }
    }

    // MPRIS doesn't push position updates; poke it often enough for synced lyrics
    Timer {
        interval: 250
        running: root.opened && root.playing
        repeat: true
        onTriggered: root.player.positionChanged()
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
        WlrLayershell.namespace: "quickshell-music"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // dim + click-outside-to-close
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.opened ? 0.5 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Main.anim
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        // ClippingRectangle (not clip: true) keeps the cover wash inside the rounded corners
        ClippingRectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(1100, parent.width - 80)
            height: Math.min(660, parent.height - 80)
            radius: 16
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1

            scale: root.opened ? 1 : 0.94
            opacity: root.opened ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: Main.anim
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Main.anim
                }
            }

            // swallow clicks so they don't reach the backdrop
            MouseArea {
                anchors.fill: parent
            }

            // blurred cover wash over the whole card. The blur runs on a 1/8-size copy that
            // is scaled up: same look, a fraction of the GPU work (matters on laptop iGPUs)
            Item {
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
                anchors.margins: 28
                focus: true

                Keys.onPressed: event => vimKeys.handle(event)

                VimKeys {
                    id: vimKeys
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
                        { keys: "o", desc: "open app", run: () => { if (root.player?.canRaise) { root.player.raise(); root.hide(); } } },
                        { keys: "q", desc: "close", run: () => root.hide() },
                        { keys: "<Esc>", desc: "", run: () => root.hide() }
                    ]
                }

                // ── header: player tabs + actions ─────────────────────
                Item {
                    id: header
                    width: parent.width
                    height: 32

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: root.players
                            Rectangle {
                                id: tab
                                required property var modelData
                                readonly property bool current: modelData === root.player
                                height: 30
                                width: tabText.implicitWidth + 24
                                radius: 15
                                color: current ? Main.theme.colFg : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.3))

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Main.anim
                                    }
                                }

                                Text {
                                    id: tabText
                                    anchors.centerIn: parent
                                    text: (tab.modelData.isPlaying ? "󰐊  " : "󰏤  ") + tab.modelData.identity
                                    color: tab.current ? Main.theme.colBg : Main.theme.colFg
                                    font: Main.barFont
                                }
                                MouseArea {
                                    id: tabMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selected = tab.modelData
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            rightPadding: 8
                            text: "? keys"
                            color: Main.theme.colAccentDark
                            font: Main.smallFont
                        }

                        // lyrics toggle (opt-in: it sends artist/title to lrclib.net)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 30
                            width: lyricsText.implicitWidth + 24
                            radius: 15
                            color: Lyrics.enabled ? Main.theme.colFg : (lyricsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.3))

                            Behavior on color {
                                ColorAnimation {
                                    duration: Main.anim
                                }
                            }

                            Text {
                                id: lyricsText
                                anchors.centerIn: parent
                                text: "󰎈  Lyrics"
                                color: Lyrics.enabled ? Main.theme.colBg : Main.theme.colFg
                                font: Main.barFont
                            }
                            MouseArea {
                                id: lyricsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Lyrics.setEnabled(!Lyrics.enabled)
                            }
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.player?.canRaise ?? false
                            icon: "󰏌"
                            onClicked: {
                                root.player.raise();
                                root.hide();
                            }
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰅖"
                            onClicked: root.hide()
                        }
                    }
                }

                // ── main: cover | info, lyrics, transport ──────
                Item {
                    id: main
                    anchors.top: header.bottom
                    anchors.topMargin: 24
                    anchors.bottom: spectrum.top
                    anchors.bottomMargin: 20
                    width: parent.width

                    readonly property real coverSize: Math.min(height, 380)

                    RectangularShadow {
                        anchors.fill: cover
                        radius: cover.radius
                        blur: 32
                        offset.y: 10
                        color: Qt.rgba(0, 0, 0, 0.7)
                    }

                    ClippingRectangle {
                        id: cover
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: main.coverSize
                        height: main.coverSize
                        radius: 10
                        color: Main.theme.colSurface

                        // generic cover: browsers, or players without art
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
                                    font.family: Main.fontFamily
                                    font.pixelSize: 96
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

                    // right column
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
                                font.family: Main.fontFamily
                                font.pixelSize: 30
                                font.weight: Font.DemiBold
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
                                font.pixelSize: 17
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
                                    Rectangle {
                                        required property var modelData
                                        height: 22
                                        width: chipText.implicitWidth + 16
                                        radius: 11
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        border.color: Qt.rgba(1, 1, 1, 0.1)
                                        border.width: 1
                                        Text {
                                            id: chipText
                                            anchors.centerIn: parent
                                            text: String(parent.modelData)
                                            color: Main.theme.colAccentLight
                                            font: Main.smallFont
                                        }
                                    }
                                }
                            }
                        }

                        // lyrics (or a hint when off / missing)
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

                        // seek + transport
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
                                        color: Qt.rgba(1, 1, 1, 0.12)

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

                                    // hover time preview
                                    Rectangle {
                                        visible: seekMouse.containsMouse && seek.len > 0
                                        x: Math.max(0, Math.min(seek.width - width, seekMouse.mouseX - width / 2))
                                        y: -height - 6
                                        width: hoverTime.implicitWidth + 12
                                        height: 20
                                        radius: 4
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
                                        radius: 22
                                        icon: "󰒮"
                                        opacity: root.player?.canGoPrevious ? 1 : 0.4
                                        onClicked: root.player?.previous()
                                    }

                                    // big filled play/pause
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 60
                                        height: 60
                                        radius: 30
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
                                            font.family: Main.fontFamily
                                            font.pixelSize: 28
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
                                        radius: 22
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

                                // player volume, when the player exposes it over MPRIS
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

                // ── spectrum across the bottom ─────────────────────────
                Spectrum {
                    id: spectrum
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 110
                    playing: root.opened && root.playing
                }
            }

            KeyHelp {
                vimKeys: vimKeys
            }
        }
    }
}
