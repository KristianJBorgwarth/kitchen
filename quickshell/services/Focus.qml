pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// The focused window, and for terminals the program running inside them. Ghostty runs
// every window in one process, so the process tree can't tell windows apart; instead
// this reads the title, which ghostty's shell integration sets to the running command
// (and nvim, claude etc. set themselves).
Singleton {
    id: root
    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property string appId: toplevel?.appId ?? ""
    readonly property string title: toplevel?.title ?? ""

    readonly property var terminals: ["ghostty", "kitty", "foot", "alacritty", "wezterm", "konsole", "gnome-terminal", "xterm"]
    readonly property bool isTerminal: terminals.some(t => appId.toLowerCase().includes(t))

    // first word of a terminal title → [display name, glyph]; a matching desktop entry adds its icon
    readonly property var programs: ({
            nvim: ["Neovim", ""],
            vim: ["Vim", ""],
            vi: ["Vim", ""],
            btop: ["btop", "󰍛"],
            htop: ["htop", "󰍛"],
            top: ["top", "󰍛"],
            lazygit: ["lazygit", ""],
            git: ["git", ""],
            k9s: ["k9s", "󱃾"],
            kubectl: ["kubectl", "󱃾"],
            ssh: ["ssh", "󰣀"],
            newsboat: ["newsboat", "󰑫"],
            man: ["man", "󰈙"],
            less: ["less", "󰈙"],
            python: ["Python", ""],
            python3: ["Python", ""],
            node: ["Node", "󰎙"],
            npm: ["npm", "󰎙"],
            cargo: ["cargo", ""],
            go: ["go", ""],
            docker: ["docker", "󰡨"],
            claude: ["Claude", "󰚩"],
            yazi: ["yazi", "󰉋"],
            ranger: ["ranger", "󰉋"],
            make: ["make", "󰆍"]
        })

    // { name, icon, glyph, detail } for what's in a terminal, or null for a plain shell
    function inner(t) {
        t = t.trim();
        // claude code puts a spinner glyph in front of its session title
        const spin = t.match(/^[◐◑◒◓✳✻✽✶✢·⠁-⣿]\s*(.*)$/);
        if (spin)
            return describe("claude", spin[1]);
        const first = (t.split(/\s+/)[0] ?? "").split("/").pop();
        const rest = t.slice(t.indexOf(first) + first.length).trim();
        if (programs[first])
            return describe(first, rest);
        return null;
    }

    function describe(prog, detail) {
        // exact id only: a fuzzy match would hand e.g. "go" some unrelated app's icon
        const entry = DesktopEntries.byId(prog);
        const known = programs[prog];
        return {
            name: known?.[0] ?? entry?.name ?? prog,
            icon: entry?.icon ?? "",
            glyph: known?.[1] ?? "",
            detail
        };
    }

    readonly property var program: isTerminal ? inner(title) : null
    readonly property var appEntry: Apps.findEntry(appId)

    readonly property string name: program?.name ?? appEntry?.name ?? appId
    readonly property string icon: program ? program.icon : (appEntry?.icon ?? "")
    readonly property string glyph: program?.glyph ?? ""
    // a plain shell's title is just its directory; apps' titles are page/document names
    readonly property string detail: program ? program.detail : title
}
