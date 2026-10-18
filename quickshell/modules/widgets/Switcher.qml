pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

// Workspace switcher: a carousel of workspace snapshots, the selected one large in the
// middle. Live previews aren't possible: Quickshell only captures single windows through
// a Hyprland protocol, and a monitor capture would include this overlay itself. Instead
// each monitor is captured into its current workspace's snapshot shortly after switching
// and every few seconds, but only while no modal is open.
Scope {
    id: root
    readonly property alias opened: modal.opened
    property string query: ""
    // tracked by name so a refresh of the list doesn't move the selection
    property string selectedName: ""
    // false right after opening: the list is still arriving from swaymsg, so the carousel
    // jumps to the selection instead of sliding (a slide could stop on the wrong card)
    property bool settled: false

    readonly property string q: query.trim().toLowerCase()
    readonly property var spaces: Windows.workspaces.slice().sort((a, b) => (a.rect.x - b.rect.x) || ((a.num < 0) - (b.num < 0)) || (a.num - b.num) || a.name.localeCompare(b.name)).filter(ws => q === "" || ws.windows.some(w => matches(w)))
    readonly property int selectedIndex: Math.max(0, spaces.findIndex(w => w.name === selectedName))
    readonly property var selected: spaces[selectedIndex] ?? null

    function matches(win) {
        return q !== "" && (win.appId + " " + win.title).toLowerCase().includes(q);
    }

    onSpacesChanged: {
        if (!spaces.some(ws => ws.name === selectedName))
            selectedName = spaces[0]?.name ?? "";
    }

    function toggle() {
        if (opened) {
            modal.hide();
            return;
        }
        query = "";
        selectedName = I3.focusedWorkspace?.name ?? "";
        Windows.active = true;
        settled = false;
        settleOpen.restart();
        modal.show();
    }

    function step(d) {
        if (spaces.length > 0)
            selectedName = spaces[Math.max(0, Math.min(spaces.length - 1, selectedIndex + d))].name;
    }

    function commit() {
        const hit = selected?.windows.find(w => matches(w));
        if (hit)
            Windows.focusWindow(hit.id);
        else if (selected)
            Windows.focusWorkspace(selected.name);
        modal.hide();
    }

    Timer {
        id: settleOpen
        interval: 300
        onTriggered: root.settled = true
    }

    // ── snapshots ─────────────────────────────────────────────
    function snapshotItem(name) {
        for (let i = 0; i < shots.count; i++) {
            const it = shots.itemAt(i);
            if (it?.wsName === name)
                return it;
        }
        return null;
    }

    function capture() {
        if (ModalHost.active)
            return;
        for (const m of I3.monitors.values) {
            const it = snapshotItem(m.activeWorkspace?.name ?? "");
            const screen = Quickshell.screens.find(s => s.name === m.name);
            if (!it || !screen)
                continue;
            // null then the screen: re-setting the same source wouldn't capture again
            it.captureSource = null;
            it.captureSource = screen;
            it.taken = true;
        }
    }

    // let a switch finish painting before capturing it
    Timer {
        id: settle
        interval: 400
        onTriggered: root.capture()
    }
    Connections {
        target: I3
        function onFocusedWorkspaceChanged() {
            settle.restart();
        }
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.capture()
    }

    Modal {
        id: modal
        maxWidth: 1600
        maxHeight: 760
        padding: 24
        onClosed: Windows.active = false
        bindings: [
            { keys: "l", desc: "next", run: () => root.step(1) },
            { keys: "h", desc: "previous", run: () => root.step(-1) },
            { keys: "<Right>", desc: "", run: () => root.step(1) },
            { keys: "<Left>", desc: "", run: () => root.step(-1) },
            { keys: "<Tab>", desc: "", run: () => root.step(1) },
            { keys: "<S-Tab>", desc: "", run: () => root.step(-1) },
            { keys: "gg", desc: "first", run: () => root.step(-1e3) },
            { keys: "G", desc: "last", run: () => root.step(1e3) },
            { keys: "<CR>", desc: "switch", run: () => root.commit() },
            { keys: "/", desc: "search windows", run: () => search.forceActiveFocus() },
            { keys: "<Esc>", desc: "", run: () => root.query ? root.query = "" : modal.hide() }
        ]

        // one capture per workspace, kept between opens; the carousel shows them through
        // ShaderEffectSources cropped to the workspace area. Off-screen rather than
        // invisible: an invisible source doesn't render into those
        Item {
            x: -100000
            Repeater {
                id: shots
                model: I3.workspaces.values
                ScreencopyView {
                    required property var modelData
                    readonly property string wsName: modelData.name
                    property bool taken: false
                    readonly property var screen: Quickshell.screens.find(s => s.name === modelData.monitor?.name) ?? null
                    width: (screen?.width ?? 1920) / 2
                    height: (screen?.height ?? 1080) / 2
                    live: false
                }
            }
        }

        Item {
            id: header
            width: parent.width
            height: 36

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Workspaces"
                color: Main.theme.colFg
                font.family: Main.fontFamily
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 280
                    height: 32
                    radius: 16
                    color: Main.theme.colSurface
                    border.color: search.activeFocus ? Main.theme.colBlue : Main.theme.colMuted
                    border.width: 1

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        color: Main.theme.colAccentMid
                        font: Main.barFont
                    }
                    TextInput {
                        id: search
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query
                        onTextEdited: root.query = text
                        color: Main.theme.colFg
                        selectionColor: Main.theme.colAccentDark
                        font: Main.barFont
                        clip: true

                        Keys.onReturnPressed: root.commit()
                        Keys.onEscapePressed: modal.body.forceActiveFocus()
                        Keys.onTabPressed: root.step(1)
                        Keys.onBacktabPressed: root.step(-1)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text && !search.activeFocus
                            text: "/ to search windows"
                            color: Main.theme.colAccentDark
                            font: Main.barFont
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "? keys"
                    color: Main.theme.colAccentDark
                    font: Main.smallFont
                }
            }
        }

        // ── carousel ──────────────────────────────────────────
        ListView {
            id: carousel
            anchors.top: header.bottom
            anchors.topMargin: 16
            anchors.bottom: info.top
            anchors.bottomMargin: 16
            width: parent.width
            orientation: ListView.Horizontal
            interactive: false
            clip: true
            spacing: 28

            readonly property real slotW: width * 0.58
            model: ScriptModel {
                values: root.opened ? root.spaces : []
            }
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - slotW) / 2
            preferredHighlightEnd: (width + slotW) / 2
            highlightMoveDuration: root.settled ? 180 : 0
            highlightMoveVelocity: -1

            // set explicitly rather than bound: replacing rows (every refresh) resets the
            // view's own index, and a binding to an unchanged value wouldn't put it back
            function sync() {
                if (count === 0)
                    return;
                currentIndex = root.selectedIndex;
                if (!root.settled)
                    positionViewAtIndex(root.selectedIndex, ListView.Center);
            }
            onCountChanged: sync()
            Connections {
                target: root
                function onSelectedIndexChanged() {
                    carousel.sync();
                }
                function onSpacesChanged() {
                    carousel.sync();
                }
            }
            Timer {
                interval: 50
                repeat: true
                running: root.opened && !root.settled
                onTriggered: carousel.sync()
            }

            delegate: Item {
                id: slot
                required property var modelData
                required property int index
                readonly property bool current: index === root.selectedIndex
                // distance from the middle in slots, for the depth effect
                readonly property real d: (x + width / 2 - carousel.contentX - carousel.width / 2) / carousel.slotW
                readonly property real ad: Math.min(2, Math.abs(d))
                readonly property var ws: modelData
                readonly property var shot: root.snapshotItem(ws.name)
                readonly property real aspect: ws.rect.width / Math.max(1, ws.rect.height)

                width: carousel.slotW
                height: carousel.height
                z: 10 - ad
                scale: 1 - 0.24 * ad
                opacity: 1 - 0.4 * ad

                // pulls neighbours in under the middle card, like a stack
                transform: Translate {
                    x: -slot.d * carousel.slotW * 0.12
                }

                RectangularShadow {
                    anchors.fill: frame
                    radius: frame.radius
                    blur: 30
                    offset.y: 8
                    color: Qt.rgba(0, 0, 0, 0.6)
                }

                Rectangle {
                    id: frame
                    anchors.centerIn: parent
                    height: Math.min(parent.height, parent.width / slot.aspect)
                    width: height * slot.aspect
                    radius: 12
                    color: Main.theme.colSurface
                    border.color: slot.current ? Main.theme.colBlue : Qt.rgba(1, 1, 1, 0.14)
                    border.width: slot.current ? 2 : 1

                    ClippingRectangle {
                        id: preview
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 10
                        color: Main.theme.colBg

                        // the snapshot, cropped from the monitor capture to this workspace's area
                        ShaderEffectSource {
                            id: picture
                            anchors.fill: parent
                            visible: slot.shot?.taken ?? false
                            sourceItem: slot.shot
                            readonly property real k: (slot.shot?.width ?? 1) / Math.max(1, slot.ws.outputRect.width)
                            sourceRect: Qt.rect((slot.ws.rect.x - slot.ws.outputRect.x) * k, (slot.ws.rect.y - slot.ws.outputRect.y) * k, slot.ws.rect.width * k, slot.ws.rect.height * k)
                        }

                        // never-visited workspaces: their window layout with icons
                        Repeater {
                            model: picture.visible ? [] : slot.ws.windows.slice().sort((a, b) => a.floating - b.floating)
                            Rectangle {
                                required property var modelData
                                readonly property real s: preview.width / Math.max(1, slot.ws.rect.width)
                                x: modelData.rect.x * s
                                y: modelData.rect.y * s
                                width: modelData.rect.width * s
                                height: modelData.rect.height * s
                                radius: 6
                                color: Main.theme.colSurface
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.min(48, parent.height / 3)
                                    source: parent.modelData.icon ? Quickshell.iconPath(parent.modelData.icon, true) : ""
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !picture.visible && slot.ws.windows.length === 0
                            text: "empty"
                            color: Main.theme.colMuted
                            font: Main.barFont
                        }

                        // search hits outlined on top of the picture
                        Repeater {
                            model: root.q ? slot.ws.windows.filter(w => root.matches(w)) : []
                            Rectangle {
                                required property var modelData
                                readonly property real s: preview.width / Math.max(1, slot.ws.rect.width)
                                x: modelData.rect.x * s
                                y: modelData.rect.y * s
                                width: modelData.rect.width * s
                                height: modelData.rect.height * s
                                radius: 6
                                color: "transparent"
                                border.color: Main.theme.colBlue
                                border.width: 2
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: slot.current ? root.commit() : root.selectedName = slot.ws.name
                    }
                }
            }
        }

        // ── selected workspace details ────────────────────────
        Item {
            id: info
            anchors.bottom: parent.bottom
            width: parent.width
            height: 64

            Column {
                anchors.centerIn: parent
                spacing: 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selected?.name ?? ""
                        color: Main.theme.colFg
                        font.family: Main.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.selected?.output ?? "") + "  ·  " + (root.selectedIndex + 1) + " / " + root.spaces.length
                        color: Main.theme.colAccentMid
                        font: Main.smallFont
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16
                    Repeater {
                        model: root.selected?.windows ?? []
                        Row {
                            required property var modelData
                            spacing: 6
                            opacity: root.q === "" || root.matches(modelData) ? 1 : 0.35
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 16
                                source: parent.modelData.icon ? Quickshell.iconPath(parent.modelData.icon, true) : ""
                                visible: parent.modelData.icon !== ""
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 260)
                                text: parent.modelData.title
                                color: Main.theme.colAccentLight
                                font: Main.smallFont
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
