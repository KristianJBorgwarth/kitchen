pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland's bindings, read live from `hyprctl binds`. Each one carries a description,
// "Section|Description" or "Section|Description|program" (see hypr/conf/keybinds.lua):
// binds with the same description merge, and runs like Super+1…9 collapse into one row.
Singleton {
    id: root
    // [{ title, rows: [{ desc, detail, combos: [[key, …], …], app, glyph }] }]
    property var sections: []

    function reload(): void {
        bindsProc.running = true;
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: root.sections = root.parse(this.text)
        }
    }

    Component.onCompleted: reload()

    readonly property var keyNames: ({
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
            "mouse:272": "LMB",
            "mouse:273": "RMB",
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
    // modmask bits, in the order the caps are drawn
    readonly property var mods: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]

    function keys(modmask, key) {
        const out = mods.filter(m => modmask & m[0]).map(m => m[1]);
        out.push(keyNames[key.toLowerCase()] ?? (key.length === 1 ? key.toUpperCase() : key));
        return out;
    }

    readonly property var arrows: ({ left: "󰁍", down: "󰁅", up: "󰁝", right: "󰁔" })
    readonly property var glyphs: [[/^Close window$|^Leave mode$/, "󰅖"], [/^Reload/, "󰑓"], [/^Move window|^Send to/, "󰆾"], [/^Workspace/, "󰍹"], [/^Fullscreen$/, "󰊓"], [/floating|scratchpad/i, "󰕰"], [/^Resize|^Shrink|^Grow/, "󰩨"], [/^Volume mute$/, "󰝟"], [/^Volume/, "󰕾"], [/^Mic/, "󰍭"], [/^Brightness/, "󰃠"]]

    function glyph(section, desc) {
        const m = desc.match(/^Focus (left|down|up|right)$/);
        if (m)
            return arrows[m[1]];
        const hit = glyphs.find(g => g[0].test(desc));
        if (hit)
            return hit[1];
        return ({ Apps: "󰘳", Quickshell: "󰣆" })[section] ?? "󰌌";
    }

    function parse(text) {
        let binds;
        try {
            binds = JSON.parse(text);
        } catch (e) {
            return root.sections;
        }
        const sections = [];
        const byTitle = {};
        for (const b of binds) {
            const [title, desc, prog] = (b.description || "General|" + b.key).split("|");
            let section = byTitle[title];
            if (!section) {
                section = byTitle[title] = { title, rows: [], byDesc: {} };
                sections.push(section);
            }
            const combo = keys(b.modmask, b.key);
            const row = section.byDesc[desc];
            if (row) {
                row.combos.push(combo);
                continue;
            }
            const entry = prog ? Apps.findEntry(prog) : null;
            const newRow = { desc, detail: entry?.name ?? "", app: entry?.icon ?? "", glyph: glyph(title, desc), combos: [combo], cmd: desc };
            section.byDesc[desc] = newRow;
            section.rows.push(newRow);
        }

        return sections.map(s => ({
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
