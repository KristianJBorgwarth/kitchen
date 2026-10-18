pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

// App launcher. One search box over apps (ranked by how often and recently they're
// launched), app sub-actions, open windows, shell quick actions and a calculator.
// Prefixes: ">" runs a command, "?" searches the web.
Scope {
    id: root
    readonly property alias opened: modal.opened
    property string query: ""
    property int selected: 0
    readonly property string terminal: "ghostty"

    function toggle() {
        if (opened) {
            modal.hide();
            return;
        }
        query = "";
        selected = 0;
        modal.show();
        search.forceActiveFocus();
    }

    // ── ranking ───────────────────────────────────────────────
    function score(q, text) {
        if (!text)
            return 0;
        const t = String(text).toLowerCase();
        if (t === q)
            return 100;
        if (t.startsWith(q))
            return 80;
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 60;
        if (t.includes(q))
            return 40;
        // letters in order, e.g. "ff" → firefox
        let i = 0;
        for (const c of t) {
            if (c === q[i])
                i++;
        }
        return i === q.length ? 15 : 0;
    }

    // launches per desktop entry id: { n, last }; recent and frequent apps float up
    function frecency(id) {
        const f = stats.launches[id];
        if (!f)
            return 0;
        const days = (Date.now() - f.last) / 86400000;
        const decay = days < 1 ? 1 : days < 7 ? 0.7 : 0.4;
        return Math.min(25, 8 * Math.log2(f.n + 1)) * decay;
    }

    function remember(id) {
        const all = Object.assign({}, stats.launches);
        all[id] = { n: (all[id]?.n ?? 0) + 1, last: Date.now() };
        stats.launches = all;
    }

    // plain arithmetic only; the character check is what makes eval safe here
    function calculate(t) {
        const expr = t.startsWith("=") ? t.slice(1) : t;
        if (!/^[\d\s+\-*/().,%^]+$/.test(expr) || !/\d/.test(expr) || !/[+\-*/%^]/.test(expr.replace(/^\s*-/, "")))
            return null;
        try {
            const v = Function("return (" + expr.replace(/,/g, ".").replace(/\^/g, "**") + ")")();
            return typeof v === "number" && isFinite(v) ? Number(v.toPrecision(12)) : null;
        } catch (e) {
            return null;
        }
    }

    readonly property var quickActions: [
        { name: "Control center", glyph: "󰒓", keys: "settings volume wifi bluetooth", run: () => ControlCenter.show() },
        { name: "Notifications", glyph: "󰂚", keys: "alerts history", run: () => { ControlCenter.openTab("notifications"); ControlCenter.show(); } },
        { name: "Music player", glyph: "󰎈", keys: "now playing song", run: () => MusicPlayer.show() },
        { name: "System monitor", glyph: "󰓅", keys: "performance cpu memory processes", run: () => SystemMonitor.show() },
        { name: "Keybinds", glyph: "󰌌", keys: "shortcuts cheatsheet help", run: () => Cheatsheet.show() },
        { name: "Workspaces", glyph: "󰕰", keys: "switcher overview", run: () => Switcher.toggle() },
        { name: "Lock screen", glyph: "󰌾", keys: "lock", run: () => Session.lock() },
        { name: "Suspend", glyph: "󰤄", keys: "sleep", run: () => Session.suspend() },
        { name: "Log out", glyph: "󰍃", keys: "logout exit sway", run: () => Session.logout() },
        { name: "Reboot", glyph: "󰜉", keys: "restart", run: () => Session.reboot() },
        { name: "Power off", glyph: "󰐥", keys: "shutdown poweroff", run: () => Session.poweroff() }
    ]

    readonly property var results: build(query)

    function build(raw) {
        const t = raw.trim();
        const out = [];

        if (t.startsWith(">")) {
            const cmd = t.slice(1).trim();
            if (cmd) {
                out.push({ kind: "run", name: cmd, sub: "Run command", glyph: "", run: () => Quickshell.execDetached(["sh", "-c", cmd]) });
                out.push({ kind: "run", name: cmd, sub: "Run in " + terminal, glyph: "", run: () => Quickshell.execDetached([terminal, "-e", "sh", "-c", cmd + "; exec ${SHELL:-sh}"]) });
            }
            return out;
        }
        if (t.startsWith("?")) {
            const q = t.slice(1).trim();
            if (q)
                out.push(web(q));
            return out;
        }

        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const q = t.toLowerCase();
        if (!q)
            return apps.map(e => app(e, frecency(e.id))).sort((a, b) => (b.score - a.score) || a.name.localeCompare(b.name));

        const calc = calculate(t);
        if (calc !== null)
            out.push({ kind: "calc", name: String(calc), sub: "= " + t.replace(/^=/, "").trim() + "  ·  Enter copies", glyph: "󰃬", score: 1000, run: () => Quickshell.clipboardText = String(calc) });

        for (const e of apps) {
            const s = Math.max(score(q, e.name), score(q, e.genericName) * 0.7, score(q, (e.keywords ?? []).join(" ")) * 0.6, score(q, e.id) * 0.5);
            if (s > 0)
                out.push(app(e, s + frecency(e.id)));
            for (const a of e.actions ?? []) {
                const sa = score(q, e.name + " " + a.name) * 0.8;
                if (sa > 0)
                    out.push({ kind: "action", name: a.name, sub: e.name, icon: a.icon || e.icon, score: sa, run: () => { root.remember(e.id); a.execute(); } });
            }
        }

        for (const w of ToplevelManager.toplevels.values) {
            const s = Math.max(score(q, w.title) * 0.7, score(q, w.appId) * 0.9);
            if (s > 0)
                out.push({ kind: "window", name: w.title || w.appId, sub: "Open window  ·  " + (Apps.findEntry(w.appId)?.name ?? w.appId), icon: Apps.icon(w.appId), score: s + 5, run: () => w.activate() });
        }

        for (const qa of quickActions) {
            const s = Math.max(score(q, qa.name), score(q, qa.keys) * 0.6);
            if (s > 0)
                out.push({ kind: "shell", name: qa.name, sub: "Shell", glyph: qa.glyph, score: s, run: qa.run });
        }

        out.sort((a, b) => b.score - a.score);
        const top = out.slice(0, 40);
        top.push(web(t));
        return top;
    }

    function app(e, score) {
        return { kind: "app", name: e.name, sub: e.genericName || e.comment || "", icon: e.icon, score, run: () => { root.remember(e.id); e.execute(); } };
    }

    // a new Brave window opens on the current workspace; a plain URL open would add a tab
    // to whichever Brave window exists, possibly on another workspace. brave-browser is
    // the binary's name in Ubuntu's package
    function web(q) {
        const url = "https://duckduckgo.com/?q=" + encodeURIComponent(q);
        return { kind: "web", name: q, sub: "Search the web in a new Brave window", glyph: "󰖟", score: -1, run: () => Quickshell.execDetached(["sh", "-c", "exec \"$(command -v brave || command -v brave-browser)\" --new-window \"$1\"", "sh", url]) };
    }

    function launch(i) {
        const r = results[i];
        if (!r)
            return;
        modal.hide();
        r.run();
    }

    function move(d) {
        if (results.length > 0)
            selected = Math.max(0, Math.min(results.length - 1, selected + d));
    }

    onQueryChanged: selected = 0

    FileView {
        // the file only exists after the first launch
        printErrors: false
        path: Quickshell.statePath("launcher.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: stats
            property var launches: ({})
        }
    }

    Modal {
        id: modal
        maxWidth: 700
        maxHeight: Math.min(480, 66 + list.contentHeight + padding * 2)
        padding: 16
        // typing goes to the search box, so navigation sticks to keys it doesn't use
        bindings: [
            { keys: "<Down>", desc: "next", run: () => root.move(1) },
            { keys: "<Up>", desc: "previous", run: () => root.move(-1) },
            { keys: "<C-j>", desc: "next", run: () => root.move(1) },
            { keys: "<C-k>", desc: "previous", run: () => root.move(-1) },
            { keys: "<C-n>", desc: "", run: () => root.move(1) },
            { keys: "<C-p>", desc: "", run: () => root.move(-1) },
            { keys: "<Tab>", desc: "", run: () => root.move(1) },
            { keys: "<S-Tab>", desc: "", run: () => root.move(-1) },
            { keys: "<CR>", desc: "launch", run: () => root.launch(root.selected) }
        ]

        Rectangle {
            id: field
            width: parent.width
            height: 46
            radius: Main.radius
            color: Main.theme.colSurface
            border.color: Main.theme.colMuted
            border.width: 1

            Text {
                id: fieldIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.query.startsWith(">") ? "" : root.query.startsWith("?") ? "󰖟" : "󰍉"
                color: Main.theme.colAccentMid
                font: Main.barFont
            }
            TextInput {
                id: search
                anchors.left: fieldIcon.right
                anchors.leftMargin: 10
                anchors.right: hint.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                onTextEdited: root.query = text
                color: Main.theme.colFg
                selectionColor: Main.theme.colAccentDark
                font.family: Main.fontFamily
                font.pixelSize: 15
                clip: true
                Keys.onReturnPressed: root.launch(root.selected)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: "Search apps, windows, actions…"
                    color: Main.theme.colAccentDark
                    font: search.font
                }
            }
            Text {
                id: hint
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: ">  run    ?  web"
                color: Main.theme.colAccentDark
                font: Main.smallFont
            }
        }

        ListView {
            id: list
            anchors.top: field.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.selected
            highlightMoveDuration: 0
            model: ScriptModel {
                values: root.opened ? root.results : []
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === root.selected
                width: ListView.view.width
                height: 46
                radius: Main.radius
                color: current ? Qt.rgba(Main.theme.colBlue.r, Main.theme.colBlue.g, Main.theme.colBlue.b, 0.16) : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                Rectangle {
                    visible: row.current
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 26
                    radius: 2
                    color: Main.theme.colBlue
                }

                Item {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 26
                        visible: !!row.modelData.icon
                        source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !row.modelData.icon
                        text: row.modelData.glyph ?? "󰀻"
                        color: row.current ? Main.theme.colBlue : Main.theme.colAccentLight
                        font: Main.barFont
                    }
                }

                Column {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 12
                    anchors.right: kind.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        width: parent.width
                        text: row.modelData.name
                        color: Main.theme.colFg
                        font.family: Main.fontFamily
                        font.pixelSize: 14
                        font.weight: row.modelData.kind === "calc" ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.sub ?? ""
                        color: Main.theme.colAccentMid
                        font: Main.smallFont
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: kind
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ app: "app", action: "action", window: "window", shell: "shell", calc: "calc", run: "run", web: "web" })[row.modelData.kind] ?? ""
                    color: row.current ? Main.theme.colBlue : Main.theme.colAccentDark
                    font: Main.smallFont
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(row.index)
                }
            }
        }
    }
}
