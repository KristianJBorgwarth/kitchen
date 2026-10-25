pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

// Workspace switcher, two views of live workspace previews (LiveWorkspace), flipped with `o`:
// a carousel with the selected workspace large in the middle, and a grid of every workspace
// per monitor where windows can be dragged from one workspace to another.
Scope {
    id: root
    readonly property alias opened: modal.opened
    property string query: ""
    // tracked by name so a refresh of the list doesn't move the selection
    property string selectedName: ""
    // false right after opening: the list is still arriving from the compositor, so the carousel
    // jumps to the selection instead of sliding (a slide could stop on the wrong card)
    property bool settled: false
    // "carousel" or "grid"; kept between openings
    property string view: "carousel"
    // how much of the room the previews take, the same on every monitor
    readonly property real previewScale: 0.7

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
        selectedName = Compositor.focusedWorkspace;
        Windows.active = true;
        settled = false;
        settleOpen.restart();
        modal.show();
    }

    function step(d) {
        if (spaces.length > 0)
            selectedName = spaces[Math.max(0, Math.min(spaces.length - 1, selectedIndex + d))].name;
    }

    // up/down a row in the grid, staying on the monitor
    function gridMove(dy) {
        if (view !== "grid")
            return;
        const g = grid.groups.find(g => g.spaces.some(w => w.name === selectedName));
        if (!g)
            return;
        const j = g.spaces.findIndex(w => w.name === selectedName) + dy * g.cols;
        if (j >= 0 && j < g.spaces.length)
            selectedName = g.spaces[j].name;
    }

    function commit() {
        const hit = selected?.windows.find(w => matches(w));
        if (hit)
            Windows.focusWindow(hit.id);
        else if (selected && selected.name !== Compositor.focusedWorkspace)
            Windows.focusWorkspace(selected.name);
        modal.hide();
    }

    Timer {
        id: settleOpen
        interval: 300
        onTriggered: root.settled = true
    }

    Modal {
        id: modal
        // the whole screen minus the 32px edge gutter; previewScale sizes what's in it
        maxWidth: Infinity
        maxHeight: Infinity
        padding: 24
        frameless: true
        dim: 0.8
        onClosed: Windows.active = false
        bindings: [
            { keys: "l", desc: "next", run: () => root.step(1) },
            { keys: "h", desc: "previous", run: () => root.step(-1) },
            { keys: "<Right>", desc: "", run: () => root.step(1) },
            { keys: "<Left>", desc: "", run: () => root.step(-1) },
            { keys: "<Tab>", desc: "", run: () => root.step(1) },
            { keys: "<S-Tab>", desc: "", run: () => root.step(-1) },
            { keys: "j", desc: "row down (grid)", run: () => root.gridMove(1) },
            { keys: "k", desc: "row up (grid)", run: () => root.gridMove(-1) },
            { keys: "<Down>", desc: "", run: () => root.gridMove(1) },
            { keys: "<Up>", desc: "", run: () => root.gridMove(-1) },
            { keys: "o", desc: "carousel / grid", run: () => root.view = root.view === "grid" ? "carousel" : "grid" },
            { keys: "gg", desc: "first", run: () => root.step(-1e3) },
            { keys: "G", desc: "last", run: () => root.step(1e3) },
            { keys: "<CR>", desc: "switch", run: () => root.commit() },
            { keys: "/", desc: "search windows", run: () => search.forceActiveFocus() },
            { keys: "<Esc>", desc: "", run: () => root.query ? root.query = "" : modal.hide() }
        ]

        Item {
            id: header
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [
                        { view: "carousel", glyph: "󰍹" },
                        { view: "grid", glyph: "󰕰" }
                    ]
                    Rectangle {
                        id: viewButton
                        required property var modelData
                        readonly property bool on: root.view === modelData.view
                        width: viewLabel.implicitWidth + 24
                        height: 32
                        radius: Main.radius
                        color: on ? Main.theme.colSurface : "transparent"
                        border.color: on ? Main.theme.colMuted : "transparent"
                        border.width: 1

                        Text {
                            id: viewLabel
                            anchors.centerIn: parent
                            text: viewButton.modelData.glyph + "  " + viewButton.modelData.view
                            color: viewButton.on ? Main.theme.colFg : Main.theme.colAccentMid
                            font: Main.barFont
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.view = viewButton.modelData.view
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 6
                    text: "o"
                    color: Main.theme.colAccentDark
                    font: Main.smallFont
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 280
                    height: 32
                    radius: Main.radius
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
            visible: root.view === "carousel"
            orientation: ListView.Horizontal
            interactive: false
            clip: true
            spacing: 28

            readonly property real slotW: width * 0.66 * root.previewScale
            model: ScriptModel {
                objectProp: "name"
                values: root.opened && root.view === "carousel" ? root.spaces : []
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
                    height: Math.round(Math.min(parent.height * root.previewScale, parent.width / slot.aspect))
                    width: Math.round(height * slot.aspect)
                    radius: Main.radius
                    color: Main.theme.colSurface
                    border.color: slot.current ? Main.theme.colBlue : Main.theme.overlay(0.14)
                    border.width: slot.current ? 2 : 1

                    ClippingRectangle {
                        id: preview
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: Main.radius
                        color: Main.theme.colBg

                        LiveWorkspace {
                            anchors.fill: parent
                            ws: slot.ws
                            live: slot.current
                            // the ones in view keep moving, slower; the rest show one frame
                            refreshInterval: slot.ad < 1.6 ? 1000 : 0
                            query: root.q
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

        // ── grid ──────────────────────────────────────────────
        Item {
            id: grid
            anchors.top: header.bottom
            anchors.topMargin: 16
            anchors.bottom: info.top
            anchors.bottomMargin: 16
            width: parent.width
            visible: root.view === "grid"

            readonly property real gap: 48  // between monitors
            readonly property real spacing: 14  // between cells
            readonly property real labelH: 26
            // the monitors left to right: [{ output, w, h (logical size), cols, rows, spaces }]
            readonly property var groups: {
                const out = [];
                for (const ws of root.opened && root.view === "grid" ? root.spaces : []) {
                    let g = out.find(g => g.output === ws.output);
                    if (!g) {
                        g = { output: ws.output, w: Math.max(1, ws.rect.width), h: Math.max(1, ws.rect.height), spaces: [] };
                        out.push(g);
                    }
                    g.spaces.push(ws);
                }
                for (const g of out) {
                    g.cols = Math.ceil(Math.sqrt(g.spaces.length));
                    g.rows = Math.ceil(g.spaces.length / g.cols);
                }
                return out;
            }
            // one scale for all monitors, so cells keep real proportions
            readonly property real k: {
                if (groups.length === 0)
                    return 0;
                const across = groups.reduce((n, g) => n + g.cols * g.w, 0);
                let k = (width - (groups.length - 1) * gap - groups.reduce((n, g) => n + (g.cols - 1) * spacing, 0)) / across;
                for (const g of groups)
                    k = Math.min(k, (height - labelH - (g.rows - 1) * spacing) / (g.rows * g.h));
                // no cell wider than 900, then previewScale of that
                return Math.max(0, Math.min(k, 900 / Math.max(...groups.map(g => g.w))) * root.previewScale);
            }
            // the workspace a dragged window is over, "" for none
            property string dropTarget: ""

            // the workspace whose cell is under `pos` (scene coordinates), or ""
            function cellAt(pos) {
                for (let i = 0; i < monitors.count; i++) {
                    const cells = monitors.itemAt(i)?.cells;
                    for (let j = 0; j < (cells?.count ?? 0); j++) {
                        const c = cells.itemAt(j);
                        const p = c.mapFromItem(null, pos.x, pos.y);
                        if (p.x >= 0 && p.y >= 0 && p.x <= c.width && p.y <= c.height)
                            return c.ws.name;
                    }
                }
                return "";
            }

            Row {
                anchors.centerIn: parent
                spacing: grid.gap

                Repeater {
                    id: monitors
                    model: ScriptModel {
                        objectProp: "output"
                        values: grid.groups
                    }

                    Column {
                        id: monitor
                        required property var modelData
                        readonly property alias cells: cells
                        spacing: 0

                        Text {
                            height: grid.labelH
                            text: monitor.modelData.output
                            color: Main.theme.colAccentMid
                            font: Main.smallFont
                        }

                        Grid {
                            columns: monitor.modelData.cols
                            spacing: grid.spacing

                            Repeater {
                                id: cells
                                model: ScriptModel {
                                    objectProp: "name"
                                    values: monitor.modelData.spaces
                                }

                                Rectangle {
                                    id: cell
                                    required property var modelData
                                    readonly property var ws: modelData
                                    readonly property bool current: ws.name === root.selectedName
                                    readonly property bool target: grid.dropTarget === ws.name
                                    width: Math.round(monitor.modelData.w * grid.k)
                                    height: Math.round(monitor.modelData.h * grid.k)
                                    radius: Main.radius
                                    color: Main.theme.colSurface
                                    border.color: target ? Main.theme.colGreen : current ? Main.theme.colBlue : Main.theme.overlay(0.14)
                                    border.width: current || target ? 2 : 1

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedName = cell.ws.name;
                                            root.commit();
                                        }
                                    }

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: Main.radius
                                        color: Main.theme.colBg

                                        LiveWorkspace {
                                            anchors.fill: parent
                                            ws: cell.ws
                                            live: cell.current
                                            query: root.q
                                            dragLayer: liftLayer
                                            onWindowClicked: win => {
                                                Windows.focusWindow(win.id);
                                                modal.hide();
                                            }
                                            onWindowDragged: (win, pos) => grid.dropTarget = grid.cellAt(pos)
                                            onWindowDropped: (win, pos) => {
                                                const to = grid.cellAt(pos);
                                                grid.dropTarget = "";
                                                if (to && to !== cell.ws.name)
                                                    Windows.moveWindow(win.id, to);
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        width: badge.implicitWidth + 12
                                        height: badge.implicitHeight + 4
                                        radius: Main.radius
                                        color: cell.current ? Main.theme.colBlue : Qt.rgba(0, 0, 0, 0.6)
                                        Text {
                                            id: badge
                                            anchors.centerIn: parent
                                            text: cell.ws.name
                                            color: cell.current ? Main.theme.colBg : "white"
                                            font: Main.smallFont
                                        }
                                    }
                                }
                            }
                        }
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

        // a dragged window lifts into this, above everything in the modal
        Item {
            id: liftLayer
            anchors.fill: parent
            z: 100
        }
    }
}
