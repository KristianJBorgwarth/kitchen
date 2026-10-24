pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.Io

// The running compositor, sway or Hyprland, behind one interface: everything else asks here
// instead of using Quickshell.I3 / Quickshell.Hyprland, swaymsg or hyprctl directly. Only the
// backend in use is ever touched (the other module's singleton is never instantiated).
Singleton {
    id: root
    readonly property bool hypr: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""
    readonly property string name: hypr ? "hyprland" : "sway"

    readonly property string focusedMonitor: (hypr ? Hyprland.focusedMonitor?.name : I3.focusedMonitor?.name) ?? ""
    readonly property string focusedWorkspace: (hypr ? Hyprland.focusedWorkspace?.name : I3.focusedWorkspace?.name) ?? ""
    // monitors with a `name` and an `activeWorkspace` (its `name`)
    readonly property var monitors: hypr ? Hyprland.monitors.values : I3.monitors.values

    // The numbered/named workspaces that exist:
    // [{ number, name, focused, active (shown on some monitor), urgent, apps: [app id] }]
    // number is -1 for named ones (m, d, …)
    readonly property var spaces: hypr ? hyprSpaces() : swaySpaces()

    // A window opened, closed, retitled or moved. Sway's window event as is
    // ({ change, container: { id, name } }); Hyprland's is shaped the same way.
    signal windowEvent(var event)

    // command whose stdout is the window tree, for Windows.parse
    readonly property var treeCommand: hypr ? ["sh", "-c", "printf '{\"clients\":'; hyprctl -j clients; printf ',\"workspaces\":'; hyprctl -j workspaces; printf ',\"monitors\":'; hyprctl -j monitors; printf '}'"] : ["swaymsg", "-t", "get_tree", "-r"]

    function swaySpaces() {
        return I3.workspaces.values.map(w => ({
                    number: w.number,
                    name: w.name,
                    focused: w.focused,
                    active: w.active,
                    urgent: w.urgent,
                    // the app ids, from sway's layout string: "H[V[ghostty] brave-browser]"
                    apps: (w.lastIpcObject?.representation ?? "").replace(/[HVTS]?\[|\]/g, " ").split(/\s+/).filter(a => a)
                }));
    }

    function hyprSpaces() {
        return Hyprland.workspaces.values.filter(w => !w.name.startsWith("special:")).map(w => ({
                    number: /^\d+$/.test(w.name) ? Number(w.name) : -1,
                    name: w.name,
                    focused: w.focused,
                    active: w.active,
                    urgent: w.urgent,
                    apps: w.toplevels.values.map(t => t.lastIpcObject?.class || "?")
                }));
    }

    // `name` is a workspace name as the tree and `spaces` give it
    function focusWorkspace(name: string): void {
        if (hypr) {
            // the Hyprland config has workspace_back_and_forth, which would turn a switch to
            // the current workspace into a jump back to the previous one
            if (name === focusedWorkspace)
                return;
            const target = /^\d+$/.test(name) ? name : "name:" + name;
            Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ workspace = "' + target + '" })' : "workspace " + target);
        } else {
            // same with workspace_auto_back_and_forth in the sway config
            I3.dispatch("workspace --no-auto-back-and-forth " + JSON.stringify(name));
        }
    }

    // `id` is a window id from Windows.workspaces
    function focusWindow(id): void {
        if (hypr)
            Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ window = "address:' + id + '" })' : "focuswindow address:" + id);
        else
            I3.dispatch("[con_id=" + id + "] focus");
    }

    // a raw sway command
    function sway(command: string): void {
        if (!hypr)
            I3.dispatch(command);
    }

    function logout(): void {
        if (!hypr)
            Quickshell.execDetached(["swaymsg", "exit"]);
        else if (Hyprland.usingLua)
            Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null && exec hyprshutdown; exec hyprctl dispatch 'hl.dsp.exit()'"]);
        else
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
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

    Loader {
        active: !root.hypr
        sourceComponent: I3IpcListener {
            subscriptions: ["window"]
            onIpcEvent: event => root.windowEvent(JSON.parse(event.data))
        }
    }

    Loader {
        active: root.hypr
        sourceComponent: Connections {
            target: Hyprland
            function onRawEvent(event) {
                root.hyprWindowEvent(event.name, event.data);
            }
        }
    }
}
