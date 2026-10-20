pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland

// Sway workspaces and their windows, from get_tree (Quickshell's I3 module has no window
// tree). Each window is matched to its Wayland toplevel by app id + title so it can be
// screen-captured. Only refreshed while `active`, so closed it starts no processes.
Singleton {
    id: root
    property bool active: false
    // [{ name, num, output, outputRect, visible, focused, rect, windows: [{ id, pid, appId, title, rect, floating, focused, toplevel, icon }] }]
    property var workspaces: []
    property bool pending: false

    function refresh(): void {
        if (treeProc.running)
            pending = true;
        else
            treeProc.running = true;
    }

    function focusWindow(id: int): void {
        I3.dispatch("[con_id=" + id + "] focus");
    }

    function focusWorkspace(name: string): void {
        // the sway config has workspace_auto_back_and_forth, which would turn a switch to
        // the current workspace into a jump back to the previous one
        I3.dispatch("workspace --no-auto-back-and-forth " + JSON.stringify(name));
    }

    onActiveChanged: if (active) refresh()

    Process {
        id: treeProc
        command: ["swaymsg", "-t", "get_tree", "-r"]
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

    I3IpcListener {
        subscriptions: ["window"]
        onIpcEvent: if (root.active) root.refresh()
    }

    Connections {
        target: I3
        function onFocusedWorkspaceChanged() {
            if (root.active)
                root.refresh();
        }
    }

    function leaves(node) {
        const kids = (node.nodes ?? []).concat(node.floating_nodes ?? []);
        if (kids.length === 0)
            return node.type === "con" || node.type === "floating_con" ? [node] : [];
        return kids.reduce((all, k) => all.concat(leaves(k)), []);
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

        const out = [];
        for (const output of tree.nodes ?? []) {
            if (output.name === "__i3")
                continue;
            for (const ws of output.nodes ?? []) {
                if (ws.type !== "workspace")
                    continue;
                const windows = leaves(ws).map(c => {
                    const appId = c.app_id ?? c.window_properties?.class ?? "";
                    return {
                        id: c.id,
                        pid: c.pid ?? 0,
                        appId,
                        title: c.name ?? "",
                        rect: { x: c.rect.x - ws.rect.x, y: c.rect.y - ws.rect.y, width: c.rect.width, height: c.rect.height },
                        floating: c.type === "floating_con",
                        focused: c.focused,
                        toplevel: claim(appId, c.name),
                        icon: Apps.icon(appId)
                    };
                });
                out.push({
                    name: ws.name,
                    num: ws.num ?? -1,
                    output: output.name,
                    outputRect: output.rect,
                    visible: ws.visible ?? false,
                    focused: ws.focused || windows.some(w => w.focused),
                    rect: ws.rect,
                    windows
                });
            }
        }
        return out;
    }
}
