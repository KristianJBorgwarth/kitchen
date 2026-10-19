pragma Singleton

import QtQuick
import Quickshell
import qs.core
import "components"

// Draw on the live screen, e.g. during a presentation. While drawing, the mouse and keys go
// to the drawings; space pins them, so they stay on screen while everything is usable again
// (toggle() goes back to drawing). Esc, or toggle() while drawing, clears them and ends.
// Each monitor gets a DrawOverlay; the screenshot tool draws with the same tools and inks.
Scope {
    id: root
    // drawing: the overlays take the mouse and keys
    property bool active: false
    // the drawings stay up but take no input
    property bool pinned: false

    property string tool: "pen"
    readonly property var tools: [
        { id: "move", key: "v", label: "move" },
        { id: "pen", key: "p", label: "pen" },
        { id: "arrow", key: "a", label: "arrow" },
        { id: "box", key: "r", label: "box" },
        { id: "marker", key: "m", label: "marker" }
    ]
    readonly property var inks: [
        { name: "red", color: Main.theme.colRed },
        { name: "amber", color: Main.theme.colAmber },
        { name: "green", color: Main.theme.colGreen },
        { name: "blue", color: Main.theme.colBlue },
        { name: "white", color: Main.theme.colFg }
    ]
    property color ink: inks[0].color
    // [{ screen, tool, color, points: [{ x, y }] }]
    property var marks: []
    property var history: []

    function toggle(): void {
        if (active) {
            exit();
            return;
        }
        ModalHost.current?.hide();
        pinned = false;
        active = true;
    }

    function pin(): void {
        if (marks.length === 0) {
            exit();
            return;
        }
        active = false;
        pinned = true;
    }

    function exit(): void {
        active = false;
        pinned = false;
        marks = [];
        history = [];
    }

    function setTool(t: string): void {
        tool = t;
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

    function clear(): void {
        if (marks.length === 0)
            return;
        remember();
        marks = [];
    }

    Variants {
        model: root.active || root.pinned ? Quickshell.screens : []

        DrawOverlay {
            draw: root
        }
    }
}
