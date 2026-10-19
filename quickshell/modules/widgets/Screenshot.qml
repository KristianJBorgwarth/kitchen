pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import qs.core
import qs.core.components
import qs.services

// Screenshot tool. Every monitor is frozen on open, so menus and hover states hold still;
// then click a window (or empty desktop for the whole monitor), drag a region, or press f.
// With a selection, p/a/r/m/x draw on the frozen frame (pen, arrow, box, marker, pixelate).
// Enter copies and saves to ~/Pictures/Screenshots, e opens it in swappy. The capture is
// Quickshell's own screencopy: the frozen frame and the drawings on it are clipped to the
// selection and grabbed.
Scope {
    id: root
    property bool active: false
    // the selection, in logical coordinates of the monitor named `selScreen`
    property string selScreen: ""
    property rect sel: Qt.rect(0, 0, 0, 0)
    readonly property bool hasSel: selScreen !== "" && sel.width >= 1 && sel.height >= 1
    // while a region is dragged out it follows the mouse directly instead of easing
    property bool dragging: false
    property bool capturing: false
    property string action: "copy" // "copy", "edit"
    // "screen": capture the focused monitor as soon as its frame lands, no selecting
    property string instant: ""
    // the monitor the mouse is on, for f
    property string mouseScreen: ""

    // drawing: "" moves the selection, otherwise the tool the mouse draws with
    property string tool: ""
    property color ink: Main.theme.colRed
    readonly property var inks: [Main.theme.colRed, Main.theme.colAmber, Main.theme.colGreen, Main.theme.colBlue, Main.theme.colFg]
    readonly property var tools: [
        { id: "pen", key: "p", label: "pen" },
        { id: "arrow", key: "a", label: "arrow" },
        { id: "box", key: "r", label: "box" },
        { id: "marker", key: "m", label: "marker" },
        { id: "pixelate", key: "x", label: "pixelate" }
    ]
    // finished drawings, each on its monitor: [{ screen, tool, color, points: [{ x, y }] }]
    property var marks: []

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property string lastPath: ""
    property bool previewShown: false

    function start(): void {
        if (active)
            return;
        selScreen = "";
        sel = Qt.rect(0, 0, 0, 0);
        dragging = false;
        capturing = false;
        tool = "";
        marks = [];
        mouseScreen = I3.focusedMonitor?.name ?? "";
        previewShown = false;
        ModalHost.current?.hide();
        mkdir.running = true;
        Windows.active = true;
        active = true;
    }

    function close(): void {
        active = false;
        instant = "";
        Windows.active = Switcher.opened;
    }

    function clear(): void {
        selScreen = "";
        sel = Qt.rect(0, 0, 0, 0);
        tool = "";
        marks = [];
    }

    function setTool(t: string): void {
        if (hasSel)
            tool = tool === t ? "" : t;
    }

    function undo(): void {
        marks = marks.slice(0, -1);
    }

    // the rectangle spanned by a mark's first and last point
    function markRect(m: var): rect {
        const a = m.points[0];
        const b = m.points[m.points.length - 1];
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
    }

    function paintMark(ctx: var, m: var): void {
        const pts = m.points;
        const a = pts[0];
        const b = pts[pts.length - 1];
        ctx.save();
        ctx.strokeStyle = m.color;
        ctx.fillStyle = m.color;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = m.tool === "marker" ? 18 : 4;
        ctx.globalAlpha = m.tool === "marker" ? 0.35 : 1;
        if (m.tool === "pen" || m.tool === "marker") {
            ctx.beginPath();
            ctx.moveTo(a.x, a.y);
            for (const p of pts)
                ctx.lineTo(p.x, p.y);
            ctx.stroke();
        } else if (m.tool === "box") {
            const r = markRect(m);
            ctx.strokeRect(r.x, r.y, r.width, r.height);
        } else if (m.tool === "arrow") {
            const angle = Math.atan2(b.y - a.y, b.x - a.x);
            const head = 18;
            ctx.beginPath();
            ctx.moveTo(a.x, a.y);
            ctx.lineTo(b.x - Math.cos(angle) * head * 0.6, b.y - Math.sin(angle) * head * 0.6);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(b.x, b.y);
            ctx.lineTo(b.x - head * Math.cos(angle - 0.45), b.y - head * Math.sin(angle - 0.45));
            ctx.lineTo(b.x - head * Math.cos(angle + 0.45), b.y - head * Math.sin(angle + 0.45));
            ctx.closePath();
            ctx.fill();
        }
        ctx.restore();
    }

    function select(screen: string, r: rect): void {
        selScreen = screen;
        sel = r;
    }

    function finish(a: string): void {
        if (!hasSel || capturing)
            return;
        action = a;
        // the overlay holding the selection crops its frame and grabs it (see onCapturingChanged)
        capturing = true;
    }

    function store(result): void {
        const path = dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        const ok = result.saveToFile(path);
        close();
        if (!ok) {
            console.warn("screenshot: could not write " + path);
            return;
        }
        lastPath = path;
        Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\"", "sh", path]);
        if (action === "edit")
            Quickshell.execDetached(["swappy", "-f", path]);
        else
            showPreview();
    }

    function showPreview(): void {
        previewShown = true;
        previewTimer.restart();
    }

    // windows on the visible workspace of `output`, in its logical coordinates; floating last
    function windowsOn(output: string): var {
        const out = [];
        for (const ws of Windows.workspaces) {
            if (!ws.visible || ws.output !== output)
                continue;
            for (const w of ws.windows)
                out.push(Qt.rect(ws.rect.x - ws.outputRect.x + w.rect.x, ws.rect.y - ws.outputRect.y + w.rect.y, w.rect.width, w.rect.height));
        }
        return out;
    }

    // r moved and sized to fit inside `screen`
    function clampRect(screen: var, x: real, y: real, w: real, h: real): rect {
        w = Math.max(1, Math.min(screen.width, w));
        h = Math.max(1, Math.min(screen.height, h));
        return Qt.rect(Math.max(0, Math.min(screen.width - w, x)), Math.max(0, Math.min(screen.height - h, y)), w, h);
    }

    function nudge(dx: real, dy: real, dw: real, dh: real): void {
        const screen = Quickshell.screens.find(s => s.name === selScreen);
        if (!hasSel || !screen)
            return;
        sel = clampRect(screen, sel.x + dx, sel.y + dy, sel.width + dw, sel.height + dh);
    }

    function windowAt(list: var, x: real, y: real): var {
        for (let i = list.length - 1; i >= 0; i--) {
            const r = list[i];
            if (x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height)
                return r;
        }
        return null;
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
    }

    Timer {
        id: previewTimer
        interval: 5000
        onTriggered: root.previewShown = false
    }

    Variants {
        model: root.active ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            readonly property string name: modelData.name
            readonly property bool focusedScreen: name === (I3.focusedMonitor?.name ?? "")
            readonly property bool mine: root.selScreen === name
            readonly property var wins: root.windowsOn(name)
            property var hover: null
            // the mark being drawn
            property var draft: null
            // this monitor's drawings, the one in progress last
            readonly property var marks: root.marks.filter(m => m.screen === name).concat(draft ? [draft] : [])
            property real mx: -1
            property real my: -1
            readonly property bool mouseHere: root.mouseScreen === name && mx >= 0

            // the lit rectangle: the selection, else the window under the mouse; empty
            // collapses to the cursor so it grows out of and shrinks into it
            readonly property rect target: mine && root.hasSel ? root.sel : !root.hasSel && !root.dragging && hover && mouseHere ? hover : Qt.rect(Math.max(0, mx), Math.max(0, my), 0, 0)
            readonly property bool lit: target.width > 0

            screen: modelData
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-screenshot"
            WlrLayershell.keyboardFocus: focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            function grab(): void {
                const dpr = modelData.devicePixelRatio ?? 1;
                cropper.grabToImage(r => root.store(r), Qt.size(Math.round(root.sel.width * dpr), Math.round(root.sel.height * dpr)));
            }

            Connections {
                target: root
                function onCapturingChanged() {
                    if (root.capturing && win.mine)
                        Qt.callLater(win.grab);
                }
            }

            // nothing is drawn until the frame lands, so the capture never contains this overlay
            Item {
                id: stage
                anchors.fill: parent
                opacity: view.hasContent ? 1 : 0
                focus: true
                Keys.onPressed: event => keys.handle(event)

                onOpacityChanged: {
                    if (opacity === 1 && win.focusedScreen) {
                        stage.forceActiveFocus();
                        if (root.instant === "screen") {
                            root.select(win.name, Qt.rect(0, 0, win.width, win.height));
                            root.finish("copy");
                        }
                    }
                }

                // the frozen frame; while capturing it shrinks to the selection so a grab of it is the crop
                Item {
                    id: cropper
                    readonly property bool cropping: root.capturing && win.mine
                    x: cropping ? root.sel.x : 0
                    y: cropping ? root.sel.y : 0
                    width: cropping ? root.sel.width : parent.width
                    height: cropping ? root.sel.height : parent.height
                    clip: true

                    Item {
                        x: -cropper.x
                        y: -cropper.y
                        width: win.width
                        height: win.height

                        ScreencopyView {
                            id: view
                            anchors.fill: parent
                            captureSource: win.modelData
                            live: false
                        }

                        // pixelate: the frame under the rectangle sampled down to 12 px blocks
                        Repeater {
                            model: win.marks.filter(m => m.tool === "pixelate")

                            ShaderEffectSource {
                                required property var modelData
                                readonly property rect r: root.markRect(modelData)
                                x: r.x
                                y: r.y
                                width: r.width
                                height: r.height
                                sourceItem: view
                                sourceRect: r
                                textureSize: Qt.size(Math.max(1, Math.ceil(r.width / 12)), Math.max(1, Math.ceil(r.height / 12)))
                                smooth: false
                            }
                        }

                        Canvas {
                            id: canvas
                            anchors.fill: parent
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                for (const m of win.marks)
                                    root.paintMark(ctx, m);
                            }

                            Connections {
                                target: root
                                function onMarksChanged() {
                                    canvas.requestPaint();
                                }
                            }
                            Connections {
                                target: win
                                function onDraftChanged() {
                                    canvas.requestPaint();
                                }
                            }
                        }
                    }
                }

                Item {
                    id: chrome
                    anchors.fill: parent
                    visible: !root.capturing

                    property real sx: win.target.x
                    property real sy: win.target.y
                    property real sw: win.target.width
                    property real sh: win.target.height

                    Behavior on sx {
                        enabled: !root.dragging
                        NumberAnimation {
                            duration: Main.anim
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on sy {
                        enabled: !root.dragging
                        NumberAnimation {
                            duration: Main.anim
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on sw {
                        enabled: !root.dragging
                        NumberAnimation {
                            duration: Main.anim
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on sh {
                        enabled: !root.dragging
                        NumberAnimation {
                            duration: Main.anim
                            easing.type: Easing.OutCubic
                        }
                    }

                    readonly property color shade: Qt.rgba(0, 0, 0, 0.5)

                    Rectangle {
                        width: parent.width
                        height: chrome.sy
                        color: chrome.shade
                    }
                    Rectangle {
                        y: chrome.sy + chrome.sh
                        width: parent.width
                        height: parent.height - y
                        color: chrome.shade
                    }
                    Rectangle {
                        y: chrome.sy
                        width: chrome.sx
                        height: chrome.sh
                        color: chrome.shade
                    }
                    Rectangle {
                        x: chrome.sx + chrome.sw
                        y: chrome.sy
                        width: parent.width - x
                        height: chrome.sh
                        color: chrome.shade
                    }

                    Rectangle {
                        x: chrome.sx - 1
                        y: chrome.sy - 1
                        width: chrome.sw + 2
                        height: chrome.sh + 2
                        visible: chrome.sw > 1
                        color: "transparent"
                        border.color: win.mine && root.hasSel ? Main.theme.colBlue : Main.theme.colAccentLight
                        border.width: 2
                        radius: 2
                    }

                    Chip {
                        visible: win.lit
                        x: Math.max(0, Math.min(parent.width - width, chrome.sx))
                        y: chrome.sy + chrome.sh + 8 + height > parent.height ? Math.max(0, chrome.sy - height - 8) : chrome.sy + chrome.sh + 8
                        color: Main.theme.colBg
                        text: Math.round(win.target.width) + " × " + Math.round(win.target.height)
                    }

                    // magnifier: 16×16 px around the cursor at 8×, for lining edges up by the pixel
                    Rectangle {
                        id: loupe
                        readonly property int span: 16
                        readonly property int zoom: 8
                        visible: win.mouseHere && (!root.hasSel || root.dragging)
                        width: span * zoom + 2
                        height: span * zoom + 2 + 22
                        x: win.mx + 24 + width > parent.width ? win.mx - 24 - width : win.mx + 24
                        y: win.my + 24 + height > parent.height ? win.my - 24 - height : win.my + 24
                        radius: Main.radius
                        color: Main.theme.colBg
                        border.color: Main.theme.colMuted
                        border.width: 1

                        ShaderEffectSource {
                            id: lens
                            x: 1
                            y: 1
                            width: loupe.span * loupe.zoom
                            height: width
                            sourceItem: view
                            sourceRect: Qt.rect(Math.floor(win.mx) - loupe.span / 2, Math.floor(win.my) - loupe.span / 2, loupe.span, loupe.span)
                            smooth: false
                        }
                        Rectangle {
                            x: lens.x + loupe.span / 2 * loupe.zoom
                            y: lens.y + loupe.span / 2 * loupe.zoom
                            width: loupe.zoom
                            height: loupe.zoom
                            color: "transparent"
                            border.color: Main.theme.colFg
                            border.width: 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: Math.floor(win.mx) + ", " + Math.floor(win.my)
                            color: Main.theme.colAccentLight
                            font: Main.smallFont
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: moving ? Qt.ClosedHandCursor : !root.tool && win.mine && root.hasSel && inSel(mouseX, mouseY) ? Qt.OpenHandCursor : Qt.CrossCursor

                        property point origin
                        property rect startSel
                        property bool moved: false
                        property bool moving: false

                        function inSel(x, y) {
                            const s = root.sel;
                            return x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height;
                        }

                        function track(m) {
                            win.mx = m.x;
                            win.my = m.y;
                            root.mouseScreen = win.name;
                        }

                        onPositionChanged: m => {
                            track(m);
                            if (!pressed) {
                                win.hover = root.windowAt(win.wins, m.x, m.y);
                                return;
                            }
                            if (win.draft) {
                                const p = { x: m.x, y: m.y };
                                const pts = win.draft.tool === "pen" || win.draft.tool === "marker" ? win.draft.points.concat([p]) : [win.draft.points[0], p];
                                win.draft = { screen: win.name, tool: win.draft.tool, color: win.draft.color, points: pts };
                                return;
                            }
                            if (!moved && Math.hypot(m.x - origin.x, m.y - origin.y) < 4)
                                return;
                            moved = true;
                            if (moving) {
                                root.sel = root.clampRect(win.modelData, startSel.x + m.x - origin.x, startSel.y + m.y - origin.y, startSel.width, startSel.height);
                                return;
                            }
                            root.dragging = true;
                            const x = Math.max(0, Math.min(win.width, m.x));
                            const y = Math.max(0, Math.min(win.height, m.y));
                            root.select(win.name, Qt.rect(Math.min(origin.x, x), Math.min(origin.y, y), Math.abs(x - origin.x), Math.abs(y - origin.y)));
                        }
                        onPressed: m => {
                            track(m);
                            if (m.button === Qt.RightButton) {
                                if (root.tool)
                                    root.tool = "";
                                else if (root.hasSel)
                                    root.clear();
                                else
                                    root.close();
                                return;
                            }
                            if (root.tool && win.mine) {
                                win.draft = { screen: win.name, tool: root.tool, color: String(root.ink), points: [{ x: m.x, y: m.y }] };
                                return;
                            }
                            origin = Qt.point(m.x, m.y);
                            moved = false;
                            moving = win.mine && root.hasSel && inSel(m.x, m.y);
                            startSel = root.sel;
                        }
                        onReleased: m => {
                            if (m.button !== Qt.LeftButton)
                                return;
                            if (win.draft) {
                                const r = root.markRect(win.draft);
                                if (win.draft.points.length > 2 || r.width + r.height > 3)
                                    root.marks = root.marks.concat([win.draft]);
                                win.draft = null;
                                return;
                            }
                            if (root.tool)
                                return;
                            root.dragging = false;
                            const wasMoving = moving;
                            moving = false;
                            if (moved) {
                                if (!root.hasSel || root.sel.width < 3 || root.sel.height < 3)
                                    root.clear();
                                return;
                            }
                            if (wasMoving)
                                return;
                            // a plain click: the window under it, or the whole monitor on bare desktop
                            win.hover = root.windowAt(win.wins, m.x, m.y);
                            root.select(win.name, win.hover ?? Qt.rect(0, 0, win.width, win.height));
                        }
                        onDoubleClicked: m => {
                            if (!root.tool && win.mine && root.hasSel && inSel(m.x, m.y))
                                root.finish("copy");
                        }
                        onExited: win.mx = -1
                    }

                    // actions, on the focused monitor
                    Rectangle {
                        visible: win.focusedScreen
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 32
                        width: actions.implicitWidth + 16
                        height: actions.implicitHeight + 16
                        radius: Main.radius
                        color: Main.theme.colBg
                        border.color: Main.theme.colMuted
                        border.width: 1

                        Row {
                            id: actions
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: 6
                                rightPadding: 6
                                text: "󰹑"
                                color: Main.theme.colFg
                                font: Main.iconFont
                            }
                            Text {
                                visible: !root.hasSel
                                anchors.verticalCenter: parent.verticalCenter
                                rightPadding: 6
                                text: "click a window · drag a region"
                                color: Main.theme.colAccentMid
                                font: Main.smallFont
                            }
                            Chip {
                                visible: !root.hasSel
                                text: "<b>f</b>  screen"
                                clickable: true
                                onClicked: win.selectScreen()
                            }

                            Repeater {
                                model: root.hasSel ? root.tools : []
                                Chip {
                                    required property var modelData
                                    text: "<b>" + modelData.key + "</b>  " + modelData.label
                                    active: root.tool === modelData.id
                                    tint: root.ink
                                    clickable: true
                                    onClicked: root.setTool(modelData.id)
                                }
                            }
                            Row {
                                visible: root.hasSel
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: 4
                                rightPadding: 4
                                spacing: 6

                                Repeater {
                                    model: root.inks
                                    Rectangle {
                                        required property color modelData
                                        required property int index
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: modelData
                                        border.color: Main.theme.colFg
                                        border.width: Qt.colorEqual(root.ink, modelData) ? 2 : 0

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.ink = parent.modelData
                                        }
                                    }
                                }
                            }
                            Chip {
                                visible: root.hasSel
                                text: "<b>u</b>  undo"
                                clickable: root.marks.length > 0
                                opacity: root.marks.length > 0 ? 1 : 0.4
                                onClicked: root.undo()
                            }
                            Chip {
                                text: "<b>⏎</b>  copy"
                                active: root.hasSel
                                filled: true
                                tint: Main.theme.colBlue
                                clickable: root.hasSel
                                opacity: root.hasSel ? 1 : 0.4
                                onClicked: root.finish("copy")
                            }
                            Chip {
                                text: "<b>Esc</b>"
                                clickable: true
                                onClicked: root.close()
                            }
                        }
                    }
                }

                KeyHelp {
                    vimKeys: keys
                }
            }

            function selectScreen(): void {
                const s = Quickshell.screens.find(s => s.name === root.mouseScreen) ?? modelData;
                root.select(s.name, Qt.rect(0, 0, s.width, s.height));
            }

            VimKeys {
                id: keys
                bindings: [
                    { keys: "<CR>", desc: "copy + save", run: () => root.finish("copy") },
                    { keys: "e", desc: "edit in swappy", run: () => root.finish("edit") },
                    { keys: "p", desc: "pen", run: () => root.setTool("pen") },
                    { keys: "a", desc: "arrow", run: () => root.setTool("arrow") },
                    { keys: "r", desc: "box", run: () => root.setTool("box") },
                    { keys: "m", desc: "marker", run: () => root.setTool("marker") },
                    { keys: "x", desc: "pixelate", run: () => root.setTool("pixelate") },
                    { keys: "1", desc: "red", run: () => root.ink = root.inks[0] },
                    { keys: "2", desc: "amber", run: () => root.ink = root.inks[1] },
                    { keys: "3", desc: "green", run: () => root.ink = root.inks[2] },
                    { keys: "4", desc: "blue", run: () => root.ink = root.inks[3] },
                    { keys: "5", desc: "white", run: () => root.ink = root.inks[4] },
                    { keys: "u", desc: "undo", run: () => root.undo() },
                    { keys: "<C-z>", desc: "", run: () => root.undo() },
                    { keys: "f", desc: "whole monitor", run: () => win.selectScreen() },
                    { keys: "h", desc: "move left", run: () => root.nudge(-1, 0, 0, 0) },
                    { keys: "l", desc: "move right", run: () => root.nudge(1, 0, 0, 0) },
                    { keys: "k", desc: "move up", run: () => root.nudge(0, -1, 0, 0) },
                    { keys: "j", desc: "move down", run: () => root.nudge(0, 1, 0, 0) },
                    { keys: "H", desc: "move left 10", run: () => root.nudge(-10, 0, 0, 0) },
                    { keys: "L", desc: "move right 10", run: () => root.nudge(10, 0, 0, 0) },
                    { keys: "K", desc: "move up 10", run: () => root.nudge(0, -10, 0, 0) },
                    { keys: "J", desc: "move down 10", run: () => root.nudge(0, 10, 0, 0) },
                    { keys: "<C-h>", desc: "narrower", run: () => root.nudge(0, 0, -1, 0) },
                    { keys: "<C-l>", desc: "wider", run: () => root.nudge(0, 0, 1, 0) },
                    { keys: "<C-k>", desc: "shorter", run: () => root.nudge(0, 0, 0, -1) },
                    { keys: "<C-j>", desc: "taller", run: () => root.nudge(0, 0, 0, 1) },
                    { keys: "<Esc>", desc: "stop drawing / clear / cancel", run: () => root.tool ? root.tool = "" : root.hasSel ? root.clear() : root.close() },
                    { keys: "q", desc: "cancel", run: () => root.close() }
                ]
            }
        }
    }

    // the result, sliding in at the bottom-right: click opens it, drag it into an app, right-click dismisses
    PanelWindow {
        id: preview
        screen: Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name) ?? null
        visible: card.opacity > 0
        color: "transparent"
        anchors.bottom: true
        anchors.right: true
        margins.bottom: 12
        margins.right: 12
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-screenshot-preview"
        implicitWidth: 320
        implicitHeight: card.implicitHeight

        Rectangle {
            id: card
            width: parent.width
            implicitHeight: thumb.height + 54
            x: root.previewShown ? 0 : 40
            opacity: root.previewShown ? 1 : 0
            radius: Main.radius
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1

            Behavior on x {
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

            Image {
                id: thumb
                x: 8
                y: 8
                width: parent.width - 16
                height: Math.min(180, implicitHeight > 0 ? width * implicitHeight / Math.max(1, implicitWidth) : 120)
                source: root.lastPath ? "file://" + root.lastPath : ""
                sourceSize.width: 600
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: true
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                text: "<b>Copied</b>  ·  " + root.lastPath.split("/").pop()
                textFormat: Text.StyledText
                color: Main.theme.colFg
                font: Main.smallFont
                elide: Text.ElideMiddle
            }

            Item {
                id: dragProxy
                Drag.active: dragArea.drag.active
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.mimeData: ({ "text/uri-list": "file://" + root.lastPath })
                Drag.imageSource: thumb.source
                Drag.imageSourceSize: Qt.size(160, Math.round(160 * thumb.implicitHeight / Math.max(1, thumb.implicitWidth)))
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                drag.target: dragProxy
                onContainsMouseChanged: {
                    if (containsMouse)
                        previewTimer.stop();
                    else if (root.previewShown)
                        previewTimer.restart();
                }
                onClicked: m => {
                    if (m.button === Qt.LeftButton)
                        Quickshell.execDetached(["xdg-open", root.lastPath]);
                    root.previewShown = false;
                }
                onReleased: dragProxy.x = dragProxy.y = 0
            }
        }
    }
}
