pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The desktop notification server. Every notification is kept as history
// until dismissed; `popups` is the subset currently shown on screen.
Singleton {
    id: root
    // newest first
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length
    property var popups: []
    // notification id → arrival time (ms); notifications carry no timestamp of their own
    readonly property var arrived: JSON.parse(persist.arrived)
    // workspace number → highest urgency of the notifications it has that the user hasn't
    // looked at (NotificationUrgency: Low 0, Normal 1, Critical 2): only
    // where the sending window is, not every workspace with another window of the same app.
    // Kept apart from the notifications, which apps often withdraw within seconds
    readonly property var marks: JSON.parse(persist.marks)
    // notification id → workspace numbers it came from; looking at one of them clears it
    readonly property var origins: JSON.parse(persist.origins)
    // ids seen while their popup was still up: dismissed once the popup goes, so looking at
    // a workspace never cuts a popup short
    property var dismissAfterPopup: []
    // notification id → pid of the process that sent it, from scripts/notify_senders.sh
    property var senderPids: ({})
    // new notifications waiting on their sender pid and the window tree
    property var unresolved: []
    // window (con id) → titles it has shown. A browser window's title is only its current
    // tab, so this is how a Teams tab in the background still counts as that window's
    property var seenTitles: JSON.parse(persist.seenTitles)

    // survives config reloads, like the notifications themselves (keepOnReload). A string,
    // since a JS object can't be carried over into the reloaded engine
    PersistentProperties {
        id: persist
        reloadableId: "notifs"
        property string arrived: "{}"
        property string marks: "{}"
        property string origins: "{}"
        property string seenTitles: "{}"
    }

    Connections {
        target: Compositor
        function onWindowEvent(event) {
            root.noteWindow(event);
        }
    }

    // titles change constantly (terminal spinners), so they're saved for reloads in batches
    Timer {
        id: saveTitles
        interval: 5000
        onTriggered: persist.seenTitles = JSON.stringify(root.seenTitles)
    }

    Process {
        id: sendersProc
        command: [Quickshell.shellPath("scripts/notify_senders.sh")]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const [id, pid] = line.split(" ");
                root.senderPids = Object.assign({}, root.senderPids, { [id]: Number(pid) });
            }
        }
        // without it every notification falls back to guessing by app, so bring it back
        onExited: sendersRestart.start()
    }

    Timer {
        id: sendersRestart
        interval: 5000
        onTriggered: sendersProc.running = true
    }

    // the sender's pid line lands just after the notification itself
    Timer {
        id: resolveDelay
        interval: 300
        onTriggered: treeProc.running = true
    }

    // the window tree at the moment notifications arrive, so the match uses the tab
    // that was showing then
    Process {
        id: treeProc
        command: Compositor.treeCommand
        stdout: StdioCollector {
            onStreamFinished: root.resolve(Windows.parse(this.text))
        }
        onExited: if (root.unresolved.length > 0)
            running = true
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            if (!root.arrived[n.id]) {
                const a = Object.assign({}, root.arrived);
                a[n.id] = Date.now();
                persist.arrived = JSON.stringify(a);
                root.unresolved = root.unresolved.concat([n]);
                resolveDelay.restart();
            }
           // closed objects are destroyed, so never keep one in the popup list
            n.closed.connect(() => root.forget(n));
            // after a reload the old notifications are handed over again; they're history, not news
            if (n.lastGeneration)
                return;
            if (!Dnd.enabled || n.urgency === NotificationUrgency.Critical)
                root.popups = root.popups.filter(p => p.id !== n.id).concat([n]);
        }
    }

    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
        if (dismissAfterPopup.includes(n.id)) {
            dismissAfterPopup = dismissAfterPopup.filter(id => id !== n.id);
            n.dismiss();
        }
    }

    // `n` is closed (dismissed, expired or withdrawn by its app) and about to be destroyed
    function forget(n) {
        dismissAfterPopup = dismissAfterPopup.filter(id => id !== n.id);
        hidePopup(n);
        if (origins[n.id] !== undefined) {
            const o = Object.assign({}, origins);
            delete o[n.id];
            persist.origins = JSON.stringify(o);
        }
    }

    function dismiss(n) {
        dismissAfterPopup = dismissAfterPopup.filter(id => id !== n.id);
        hidePopup(n);
        n.dismiss();
    }

    function clearAll() {
        popups = [];
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    // clicking a notification: its default action if it has one
    function activate(n) {
        const action = n.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        if (!n.resident)
            dismiss(n);
    }

    // whether `n` came from the window with this app id (sway's app_id, or the X11 class).
    // Notifications name their app loosely, so this compares the desktop entry and the app
    // name against the id and its last dotted part: "org.telegram.desktop", "Telegram Desktop"
    function fromApp(n, appId) {
        const id = appId.toLowerCase();
        const tail = id.split(".").pop();
        return [n.desktopEntry, n.appName].some(c => {
            if (!c)
                return false;
            c = c.toLowerCase();
            return c === id || c === tail || c.replace(/\s+/g, "-") === id || c.replace(/\s+/g, "") === tail || id.endsWith("." + c);
        });
    }

    // the site a web notification came from: browsers put it first in the body,
    // as <a href="https://gitlab.com/">gitlab.com</a>
    function site(n) {
        const m = (n.body ?? "").match(/^\s*<a href="[a-z]+:\/\/([^\/":]+)/i);
        return m ? m[1].toLowerCase() : "";
    }

    // whether a window title looks like it shows `host`: teams.microsoft.com matches
    // "Chat | … | Microsoft Teams - Brave", gitlab.com matches "… · GitLab - Brave"
    function titleShows(title, host) {
        const t = title.toLowerCase();
        return host.split(".").slice(0, -1).filter(l => l !== "www" && l.length > 2).some(l => t.includes(l));
    }

    function noteWindow(ev) {
        const c = ev.container;
        if (!c)
            return;
        if (ev.change === "close")
            delete seenTitles[c.id];
        else if (c.name) {
            const titles = seenTitles[c.id] ?? [];
            const t = c.name.toLowerCase();
            if (!titles.includes(t))
                seenTitles[c.id] = titles.concat([t]).slice(-50);
        }
        saveTitles.restart();
    }

    // The workspaces holding the window `n` came from. Notifications don't name their window,
    // so: the window owned by the sending process (one per window for ghostty), narrowed to
    // the window showing the site for web notifications (one browser process has them all).
    // Without a sender, the app's windows count only when they're all on one workspace;
    // guessing between workspaces would light up ones the notification has nothing to do with
    function sources(n, workspaces) {
        // no flatMap in QML's JS engine
        const all = workspaces.filter(ws => ws.num > 0).reduce((out, ws) => out.concat(ws.windows.map(w => ({ w, num: ws.num }))), []);
        const pid = Number(n.hints["sender-pid"] ?? senderPids[n.id] ?? 0);
        const own = all.filter(c => pid > 0 && c.w.pid === pid);
        let hits = own.length > 0 ? own : all.filter(c => fromApp(n, c.w.appId));
        const host = site(n);
        if (host) {
            // the window showing the site now, else one that has shown it (a background tab)
            const showing = hits.filter(c => titleShows(c.w.title, host));
            hits = showing.length > 0 ? showing : hits.filter(c => (seenTitles[c.w.id] ?? []).some(t => titleShows(t, host)));
        }
        const nums = hits.map(c => c.num).filter((num, i, a) => a.indexOf(num) === i);
        return own.length > 0 || host || nums.length === 1 ? nums : [];
    }

    function resolve(workspaces) {
        // taken off the queue first: treeProc reruns while it's non-empty, so an error here
        // must not leave it filled
        const queue = unresolved;
        unresolved = [];
        // the workspace being looked at already has the user's eyes on it
        const focused = workspaces.filter(ws => ws.focused).map(ws => ws.num);
        const m = Object.assign({}, marks);
        const o = Object.assign({}, origins);
        for (const n of queue) {
            const nums = sources(n, workspaces);
            if (nums.length > 0)
                o[n.id] = nums;
            for (const num of nums)
                if (!focused.includes(num))
                    m[num] = Math.max(Number(m[num] ?? -1), n.urgency);
        }
        persist.marks = JSON.stringify(m);
        persist.origins = JSON.stringify(o);
    }

    // the workspace has been looked at: its mark is cleared, and so are the notifications
    // that came from it (after their popup, if one is still up)
    function seen(num) {
        // Low urgency is 0, so test presence rather than truthiness
        if (marks[num] !== undefined) {
            const m = Object.assign({}, marks);
            delete m[num];
            persist.marks = JSON.stringify(m);
        }
        for (const n of list.filter(n => (origins[n.id] ?? []).includes(num))) {
            if (popups.includes(n))
                dismissAfterPopup = dismissAfterPopup.concat([n.id]);
            else
                n.dismiss();
        }
    }

    // the notification's own image. Quickshell hands a file path over as
    // image://icon//tmp/…, which the icon theme lookup can't find, so load it as a file
    function image(n) {
        const i = n.image ?? "";
        return i.startsWith("image://icon//") ? "file://" + i.slice("image://icon/".length) : i;
    }

    // ms a popup stays up; 0 = until dismissed
    function timeout(n) {
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000;
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.urgency === NotificationUrgency.Low ? 4000 : 6000;
    }

    function icon(n) {
        // a temp file as app icon (browsers) is gone soon, or private to a snap's own /tmp
        const temp = n.appIcon.startsWith("file:///tmp/") || n.appIcon.startsWith("/tmp/");
        const i = (!temp && n.appIcon) || Apps.icon(n.desktopEntry || n.appName);
        if (!i)
            return "";
        // desktop entries may name the icon by absolute path, which QML would read as qrc:
        if (i.startsWith("/"))
            return "file://" + i;
        return i.includes("://") ? i : Quickshell.iconPath(i, true);
    }

    function ago(n, now) {
        const s = Math.max(0, Math.floor((now - (arrived[n.id] ?? now)) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m ago";
        if (s < 86400)
            return Math.floor(s / 3600) + "h ago";
        return Math.floor(s / 86400) + "d ago";
    }
}
