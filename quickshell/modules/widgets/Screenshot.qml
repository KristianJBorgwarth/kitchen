pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import qs.core
import qs.services
import "components"

// Screenshot tool. Every monitor is frozen on open, so menus and hover states hold still;
// then click a window (or empty desktop for the whole monitor), drag a region, or press f.
// With a selection, p/a/r/m/x draw on the frozen frame (pen, arrow, box, marker, pixelate).
// Enter copies and saves to ~/Pictures/Screenshots, e opens it in swappy. The capture is
// Quickshell's own screencopy: the frozen frame and the drawings on it are clipped to the
// selection and grabbed (ScreenshotFrame). Each monitor gets a ScreenshotOverlay.
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
    // Draw's, plus pixelate, which needs the frozen frame
    readonly property var tools: Draw.tools.concat([{ id: "pixelate", key: "x", label: "pixelate" }])
    readonly property var inks: Draw.inks
    property color ink: inks[0].color
    // finished drawings, each on its monitor: [{ screen, tool, color, points: [{ x, y }] }]
    property var marks: []
    property var history: []

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    function start(): void {
        if (active)
            return;
        clear();
        dragging = false;
        capturing = false;
        mouseScreen = I3.focusedMonitor?.name ?? "";
        preview.hide();
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
        history = [];
    }

    function select(screen: string, r: rect): void {
        selScreen = screen;
        sel = r;
    }

    function setTool(t: string): void {
        if (hasSel)
            tool = tool === t ? "" : t;
    }

    // marks as they were before each change, for undo
    function remember(): void {
        history = history.concat([marks]);
    }

    function undo(): void {
        if (history.length === 0)
            return;
        marks = history[history.length - 1];
        history = history.slice(0, -1);
    }

    function finish(a: string): void {
        if (!hasSel || capturing)
            return;
        action = a;
        // the overlay holding the selection crops its frame and grabs it into store()
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
        Quickshell.execDetached(["sh", "-c", "wl-copy -t image/png < \"$1\"", "sh", path]);
        if (action === "edit")
            Quickshell.execDetached(["swappy", "-f", path]);
        else
            preview.show(path);
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

    function windowAt(list: var, x: real, y: real): var {
        for (let i = list.length - 1; i >= 0; i--) {
            const r = list[i];
            if (x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height)
                return r;
        }
        return null;
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

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
    }

    Variants {
        model: root.active ? Quickshell.screens : []

        ScreenshotOverlay {
            shot: root
        }
    }

    ScreenshotPreview {
        id: preview
    }
}
