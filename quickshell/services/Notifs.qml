pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The desktop notification server (replaces mako). Every notification is kept as history
// until dismissed; `popups` is the subset currently shown on screen.
Singleton {
    id: root
    // newest first
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length
    property var popups: []
    // notification id → arrival time (ms); notifications carry no timestamp of their own
    readonly property var arrived: persist.arrived

    // survives config reloads, like the notifications themselves (keepOnReload)
    PersistentProperties {
        id: persist
        reloadableId: "notifs"
        property var arrived: ({})
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
            if (!persist.arrived[n.id]) {
                const a = Object.assign({}, persist.arrived);
                a[n.id] = Date.now();
                persist.arrived = a;
            }
            // closed objects are destroyed, so never keep one in the popup list
            n.closed.connect(() => root.hidePopup(n));
            // after a reload the old notifications are handed over again; they're history, not news
            if (n.lastGeneration)
                return;
            if (!Dnd.enabled || n.urgency === NotificationUrgency.Critical)
                root.popups = root.popups.filter(p => p.id !== n.id).concat([n]);
        }
    }

    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }

    function dismiss(n) {
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

    // ms a popup stays up; 0 = until dismissed
    function timeout(n) {
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000;
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.urgency === NotificationUrgency.Low ? 4000 : 6000;
    }

    function icon(n) {
        const i = n.appIcon || Apps.icon(n.desktopEntry || n.appName);
        if (!i)
            return "";
        return i.startsWith("/") || i.includes("://") ? i : Quickshell.iconPath(i, true);
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
