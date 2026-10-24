pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland behind a small interface: everything else asks here instead of using
// Quickshell.Hyprland or hyprctl directly. Dispatches are Lua, like the config (hyprland.lua).
Singleton {
    id: root
    readonly property string focusedMonitor: Hyprland.focusedMonitor?.name ?? ""
    readonly property string focusedWorkspace: Hyprland.focusedWorkspace?.name ?? ""
    // monitors with a `name` and an `activeWorkspace` (its `name`)
    readonly property var monitors: Hyprland.monitors.values

    // The numbered/named workspaces that exist:
    // [{ number, name, focused, active (shown on some monitor), urgent, apps: [app id] }]
    // number is -1 for named ones (m, d, …)
    readonly property var spaces: Hyprland.workspaces.values.filter(w => !w.name.startsWith("special:")).map(w => ({
                number: /^\d+$/.test(w.name) ? Number(w.name) : -1,
                name: w.name,
                focused: w.focused,
                active: w.active,
                urgent: w.urgent,
                apps: w.toplevels.values.map(t => t.lastIpcObject?.class || "?")
            }))

    // A window opened, closed, retitled, moved, focused or (un)floated:
    // { change, container: { id, name } }
    signal windowEvent(var event)

    // command whose stdout is the window tree, for Windows.parse
    readonly property var treeCommand: ["sh", "-c", "printf '{\"clients\":'; hyprctl -j clients; printf ',\"workspaces\":'; hyprctl -j workspaces; printf ',\"monitors\":'; hyprctl -j monitors; printf '}'"]

    // `name` is a workspace name as the tree and `spaces` give it
    function focusWorkspace(name: string): void {
        // the Hyprland config has workspace_back_and_forth, which would turn a switch to
        // the current workspace into a jump back to the previous one
        if (name === focusedWorkspace)
            return;
        const target = /^\d+$/.test(name) ? name : "name:" + name;
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + target + '" })');
    }

    // `id` is a window id from Windows.workspaces
    function focusWindow(id): void {
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + id + '" })');
    }

    // `id` is a window id from Windows.workspaces; `name` as in focusWorkspace. Stays put
    function moveWindow(id, name: string): void {
        const target = /^\d+$/.test(name) ? name : "name:" + name;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + target + '", window = "address:' + id + '", follow = false })');
    }

    // the Wayland toplevel (for screen capture) of the window with this id, or null
    function toplevel(id) {
        return Hyprland.toplevels.values.find(t => "0x" + t.address === id)?.wayland ?? null;
    }

    function logout(): void {
        Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null && exec hyprshutdown; exec hyprctl dispatch 'hl.dsp.exit()'"]);
    }

    // Hyprland event "openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE" and friends carry the
    // address without its 0x; the titles may contain commas
    function hyprWindowEvent(name, data) {
        let change, id, title;
        if (name === "openwindow") {
            const p = data.split(",");
            change = "new";
            id = p[0];
            title = p.slice(3).join(",");
        } else if (name === "windowtitlev2") {
            const i = data.indexOf(",");
            change = "title";
            id = data.slice(0, i);
            title = data.slice(i + 1);
        } else if (name === "closewindow") {
            change = "close";
            id = data;
        } else if (name === "movewindowv2") {
            change = "move";
            id = data.split(",")[0];
        } else if (name === "activewindowv2") {
            change = "focus";
            id = data;
        } else if (name === "changefloatingmode") {
            change = "floating";
            id = data.split(",")[0];
        } else {
            return;
        }
        root.windowEvent({
            change,
            container: {
                id: "0x" + id,
                name: title
            }
        });
    }

    // Quickshell only learns of windows from events; this fetches the ones already open
    Component.onCompleted: Hyprland.refreshToplevels()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root.hyprWindowEvent(event.name, event.data);
        }
    }
}
