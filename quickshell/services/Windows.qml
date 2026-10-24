pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Workspaces and their windows, from Hyprland's clients (Quickshell has no window tree). Each window is matched to its Wayland toplevel by app id + title so it can be
// screen-captured. Only refreshed while `active` (switcher, screenshot) or `peeking` (the
// bar's workspace peek), so otherwise it starts no processes.
Singleton {
    id: root
    property bool active: false
    property bool peeking: false
    readonly property bool live: active || peeking
    // [{ name, num, output, outputRect, visible, focused, rect, windows: [{ id, pid, appId, title, rect, floating, focused, toplevel, icon }] }]
    property var workspaces: []
    property bool pending: false

    function refresh(): void {
        if (treeProc.running)
            pending = true;
        else
            treeProc.running = true;
    }

    function focusWindow(id): void {
        Compositor.focusWindow(id);
    }

    function focusWorkspace(name: string): void {
        Compositor.focusWorkspace(name);
    }

    onLiveChanged: if (live) refresh()

    Process {
        id: treeProc
        command: Compositor.treeCommand
        stdout: StdioCollector {
            onStreamFinished: root.workspaces = root.parse(this.text)
        }
        onExited: {
            if (root.pending) {
                root.pending = false;
                running = true;
            }
        }
    }

    Connections {
        target: Compositor
        function onWindowEvent() {
            if (root.live)
                root.refresh();
        }
        function onFocusedWorkspaceChanged() {
            if (root.live)
                root.refresh();
        }
    }

    function parse(text) {
        let tree;
        try {
            tree = JSON.parse(text);
        } catch (e) {
            return workspaces;
        }
        const toplevels = ToplevelManager.toplevels.values.slice();
        // first unclaimed toplevel with the same app id and title, else the same app id
        const claim = (appId, title) => {
            let i = toplevels.findIndex(t => t.appId === appId && t.title === title);
            if (i < 0)
                i = toplevels.findIndex(t => t.appId === appId);
            return i < 0 ? null : toplevels.splice(i, 1)[0];
        };
        return parseHypr(tree, claim);
    }

    // `tree` is { clients, workspaces, monitors } from `hyprctl -j` (see Compositor.treeCommand).
    // Window ids are the address, and rects are in logical pixels
    function parseHypr(tree, claim) {
        const out = [];
        for (const ws of tree.workspaces ?? []) {
            // the scratchpad
            if (ws.name.startsWith("special:"))
                continue;
            const mon = (tree.monitors ?? []).find(m => m.name === ws.monitor);
            if (!mon)
                continue;
            const scale = mon.scale || 1;
            const outputRect = { x: mon.x, y: mon.y, width: Math.round(mon.width / scale), height: Math.round(mon.height / scale) };
            const windows = (tree.clients ?? []).filter(c => c.mapped && c.workspace.id === ws.id).map(c => ({
                        id: c.address,
                        pid: c.pid ?? 0,
                        appId: c.class ?? "",
                        title: c.title ?? "",
                        rect: { x: c.at[0] - mon.x, y: c.at[1] - mon.y, width: c.size[0], height: c.size[1] },
                        floating: c.floating,
                        focused: c.focusHistoryID === 0,
                        toplevel: claim(c.class ?? "", c.title ?? ""),
                        icon: Apps.icon(c.class ?? "")
                    }));
            const visible = mon.activeWorkspace?.id === ws.id;
            out.push({
                name: ws.name,
                num: /^\d+$/.test(ws.name) ? Number(ws.name) : -1,
                output: mon.name,
                outputRect,
                visible,
                focused: visible && mon.focused,
                rect: outputRect,
                windows
            });
        }
        return out;
    }
}
