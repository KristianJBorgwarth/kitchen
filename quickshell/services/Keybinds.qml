pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sway bindings (the Hyprland config mirrors them key for key) parsed into sections: comments become titles, same-command binds merge,
// and runs like $mod+1…9 collapse into one row.
Singleton {
    id: root
    // [{ title, rows: [{ desc, detail, combos: [[key, …], …], app, glyph }] }]
    property var sections: []

    function reload(): void {
        configProc.running = true;
    }

    Process {
        id: configProc
        command: [Quickshell.shellPath("scripts/sway_config.sh")]
        stdout: StdioCollector {
            onStreamFinished: root.sections = root.parse(this.text)
        }
    }

    Component.onCompleted: reload()

    readonly property var keyNames: ({
            mod4: "Super",
            mod1: "Alt",
            ctrl: "Ctrl",
            control: "Ctrl",
            shift: "Shift",
            return: "Enter",
            space: "Space",
            escape: "Esc",
            tab: "Tab",
            minus: "-",
            plus: "+",
            question: "?",
            left: "←",
            right: "→",
            up: "↑",
            down: "↓",
            xf86audioraisevolume: "Vol +",
            xf86audiolowervolume: "Vol −",
            xf86audiomute: "Mute",
            xf86audiomicmute: "Mic mute",
            xf86audioplay: "Play",
            xf86audionext: "Next",
            xf86audioprev: "Prev",
            xf86monbrightnessup: "Bright +",
            xf86monbrightnessdown: "Bright −"
        })
    readonly property var modOrder: ["Super", "Ctrl", "Alt", "Shift"]

    function keys(combo) {
        const out = combo.split("+").map(k => keyNames[k.toLowerCase()] ?? (k.length === 1 ? k.toUpperCase() : k));
        return out.sort((a, b) => {
            const ia = modOrder.indexOf(a), ib = modOrder.indexOf(b);
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
        });
    }

    readonly property var varLabels: ({
            term: "Terminal",
            menu: "App launcher",
            browser: "Browser",
            filemanager: "File manager",
            screenshot: "Screenshot"
        })
    readonly property var qsLabels: ({
            performance: "System monitor",
            music: "Music player",
            controlcenter: "Control center",
            tray: "Tray",
            keybinds: "Keybinds",
            launcher: "App launcher",
            clipboard: "Clipboard history",
            lock: "Lock screen",
            theme: "Dark / light mode",
            switcher: "Workspace switcher",
            wallpaper: "Wallpaper picker"
        })

    function titleCase(s) {
        s = s.replace(/[-_]/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // programs in an exec line (every stage of a pipeline), skipping env assignments
    // and `sh -c '…'` wrappers
    function programs(cmd) {
        let body = cmd.replace(/^exec\s+(--no-startup-id\s+)?/, "");
        body = body.replace(/^(\S+=\S+\s+)+/, "");
        if (/^(sh|bash)\s/.test(body))
            body = body.replace(/^.*?-c\s+['"]?/, "");
        return body.split("|").map(stage => {
            const words = stage.trim().replace(/^(\S+=\S+\s+)+/, "").split(/\s+/);
            return (words[0] ?? "").split("/").pop().replace(/['"]/g, "");
        }).filter(p => p);
    }

    function describe(cmd, varName) {
        let m;
        const dir = s => ({ left: "left", right: "right", up: "up", down: "down" })[s];
        if ((m = cmd.match(/^exec\s+qs\s+ipc\s+call\s+osd\s+(\S+)/)))
            return ({
                    volumeUp: { desc: "Volume up", glyph: "󰕾" },
                    volumeDown: { desc: "Volume down", glyph: "󰕾" },
                    volumeMute: { desc: "Volume mute", glyph: "󰝟" },
                    micMute: { desc: "Mic mute", glyph: "󰍭" },
                    brightnessUp: { desc: "Brightness up", glyph: "󰃠" },
                    brightnessDown: { desc: "Brightness down", glyph: "󰃠" }
                })[m[1]] ?? { desc: m[1], glyph: "󰕾" };
        if ((m = cmd.match(/^exec\s+qs\s+ipc\s+call\s+(\S+)\s+\S+/)))
            return { desc: qsLabels[m[1]] ?? titleCase(m[1]), glyph: "󰣆" };
        if (cmd.startsWith("exec")) {
            const progs = programs(cmd);
            const entry = progs.map(p => Apps.findEntry(p)).find(e => e) ?? null;
            const desc = varName ? (varLabels[varName] ?? titleCase(varName)) : (entry?.name ?? progs[0] ?? cmd);
            return { desc, detail: entry && varName ? entry.name : "", app: entry?.icon ?? "", glyph: "󰘳" };
        }
        if (cmd === "kill")
            return { desc: "Close window", glyph: "󰅖" };
        if (cmd === "reload")
            return { desc: "Reload " + (Compositor.hypr ? "Hyprland" : "sway"), glyph: "󰑓" };
        if (cmd === "exit")
            return { desc: "Exit " + (Compositor.hypr ? "Hyprland" : "sway"), glyph: "󰍃" };
        if ((m = cmd.match(/^focus\s+(left|right|up|down)$/)))
            return { desc: "Focus " + dir(m[1]), glyph: ({ left: "󰁍", down: "󰁅", up: "󰁝", right: "󰁔" })[m[1]] };
        if ((m = cmd.match(/^move\s+(left|right|up|down)$/)))
            return { desc: "Move window " + dir(m[1]), glyph: "󰆾" };
        if (cmd === "focus parent")
            return { desc: "Focus parent", glyph: "󰁝" };
        if (cmd === "focus mode_toggle")
            return { desc: "Toggle tiling / floating focus", glyph: "󰕰" };
        if ((m = cmd.match(/^move\s+container\s+to\s+workspace\s+(?:number\s+)?(\S+)$/)))
            return { desc: "Move window to workspace " + m[1], glyph: "󰆾" };
        if ((m = cmd.match(/^workspace\s+(?:number\s+)?(\S+)$/)))
            return { desc: "Workspace " + m[1], glyph: "󰍹" };
        if (cmd === "fullscreen" || cmd === "fullscreen toggle")
            return { desc: "Fullscreen", glyph: "󰊓" };
        if (cmd === "floating toggle")
            return { desc: "Toggle floating", glyph: "󰕰" };
        if (cmd === "move scratchpad")
            return { desc: "Send to scratchpad", glyph: "󰆾" };
        if (cmd === "scratchpad show")
            return { desc: "Show scratchpad", glyph: "󰕰" };
        if ((m = cmd.match(/^mode\s+"?([^"]+)"?$/)))
            return m[1] === "default" ? { desc: "Leave mode", glyph: "󰅖" } : { desc: titleCase(m[1]) + " mode", glyph: "󰩨" };
        if ((m = cmd.match(/^resize\s+(shrink|grow)\s+(width|height)/)))
            return { desc: titleCase(m[1]) + " " + m[2], glyph: "󰩨" };
        return { desc: cmd, glyph: "󰌌" };
    }

    function parse(text) {
        const vars = {};
        const sections = [];
        let section = null;
        let outerTitle = "";
        let inMode = false;

        const open = title => {
            section = { title, rows: [], byCmd: {} };
            sections.push(section);
        };
        const substitute = s => {
            // longest names first so $menu doesn't eat $menu-extra
            for (const name of Object.keys(vars).sort((a, b) => b.length - a.length))
                s = s.split("$" + name).join(vars[name]);
            return s;
        };

        for (let line of text.split("\n")) {
            line = line.trim();
            let m;
            if ((m = line.match(/^set\s+\$(\S+)\s+(.*)$/))) {
                vars[m[1]] = substitute(m[2]);
                continue;
            }
            if ((m = line.match(/^#+\s*(.+)$/))) {
                if (!inMode) {
                    outerTitle = m[1].trim();
                    open(outerTitle);
                }
                continue;
            }
            if ((m = line.match(/^mode\s+(?:--\S+\s+)*"?([^"{]+?)"?\s*\{$/))) {
                inMode = true;
                open(titleCase(m[1]) + " mode");
                continue;
            }
            if (line === "}" && inMode) {
                inMode = false;
                open(outerTitle);
                continue;
            }
            if (!(m = line.match(/^bindsym\s+((?:--\S+\s+)*)(\S+)\s+(.+)$/)))
                continue;
            if (!section)
                open("General");

            const rawCmd = m[3].trim();
            const varName = (rawCmd.match(/^exec\s+\$(\S+)$/) ?? [])[1] ?? "";
            const cmd = substitute(rawCmd);
            const combo = keys(substitute(m[2]));
            const row = section.byCmd[cmd];
            if (row) {
                row.combos.push(combo);
                continue;
            }
            const d = describe(cmd, varName);
            const newRow = { desc: d.desc, detail: d.detail ?? "", app: d.app ?? "", glyph: d.glyph, combos: [combo], cmd };
            section.byCmd[cmd] = newRow;
            section.rows.push(newRow);
        }

        return sections.filter(s => s.rows.length > 0).map(s => ({
                    title: s.title,
                    rows: collapseRuns(s.rows).map(r => Object.assign({}, r, { parts: parts(r.combos) }))
                }));
    }

    // keycaps to draw: [{ cap } | { sep }]. Combos that differ only in the last key share
    // their modifiers: Super Shift H / ← instead of Super Shift H / Super Shift ←
    function parts(combos) {
        const mods = combos[0].slice(0, -1);
        const shared = combos.every(c => c.length === combos[0].length && c.slice(0, -1).join("+") === mods.join("+"));
        const out = [];
        if (shared) {
            mods.forEach(cap => out.push({ cap }));
            combos.forEach((c, i) => {
                if (i > 0)
                    out.push({ sep: "/" });
                out.push({ cap: c[c.length - 1] });
            });
        } else {
            combos.forEach((c, i) => {
                if (i > 0)
                    out.push({ sep: "/" });
                c.forEach(cap => out.push({ cap }));
            });
        }
        return out;
    }

    // Super+1 → workspace 1 … Super+9 → workspace 9  ⇒  one "Workspace 1–9" row
    function collapseRuns(rows) {
        const groups = {};
        const out = [];
        for (const row of rows) {
            const cm = row.cmd.match(/^(.*\D)(\d+)$/);
            const combo = row.combos[0];
            const last = combo[combo.length - 1];
            if (!cm || row.combos.length !== 1 || last !== cm[2]) {
                out.push(row);
                continue;
            }
            const key = cm[1] + "|" + combo.slice(0, -1).join("+");
            if (!groups[key]) {
                groups[key] = { rows: [], nums: [] };
                out.push(groups[key]);
            }
            groups[key].rows.push(row);
            groups[key].nums.push(Number(cm[2]));
        }
        const result = [];
        for (const r of out) {
            if (!r.nums) {
                result.push(r);
            } else if (r.nums.length < 3) {
                result.push(...r.rows);
            } else {
                const first = r.rows[0];
                const lo = Math.min(...r.nums), hi = Math.max(...r.nums);
                const combo = first.combos[0].slice(0, -1).concat([lo + "…" + hi]);
                result.push(Object.assign({}, first, { desc: first.desc.replace(/\d+$/, lo + "–" + hi), combos: [combo] }));
            }
        }
        return result;
    }
}
