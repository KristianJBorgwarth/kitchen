pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland

// Browsers don't tell MPRIS which site is playing, so they only count when the site publishes
// full media metadata (YouTube does; calls, generic tabs and bare <video>s don't).
Singleton {
    id: root
    readonly property var musicApps: ["feishin"]
    readonly property var browsers: ["brave", "chromium", "chrome", "firefox", "librewolf", "vivaldi", "zen"]

    readonly property var players: Mpris.players.values.filter(p => root.allowed(p))
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

    function matches(p, names) {
        const id = (p.identity + " " + p.desktopEntry + " " + p.dbusName).toLowerCase();
        return names.some(n => id.includes(n));
    }

    // titles differ in small ways between MPRIS and the window (a symbol Brave strips
    // into a double space, etc), so compare lowercase with spacing/punctuation squashed
    function norm(s) {
        return String(s).toLowerCase().replace(/[\s\-–—|·:;,.!?'"`()\[\]{}]+/g, " ").trim();
    }

    // browser players only hand over tiny thumbnails, so widgets show generic art for them
    function isBrowser(p) {
        return !!p && !matches(p, musicApps) && matches(p, browsers);
    }

    function allowed(p) {
        // playerctld re-exports whichever player is active; it would show up twice
        if (p.dbusName.includes("playerctld"))
            return false;
        if (matches(p, musicApps))
            return true;
        if (!matches(p, browsers))
            return false;
        const url = String(p.metadata["xesam:url"] ?? "");
        if (url.includes("youtube.com") || url.includes("youtu.be"))
            return true;
        if (p.trackTitle && p.trackArtist && p.trackArtUrl && p.length > 0)
            return true;
        // fallback for sites with thin metadata: the active tab's window title says YouTube
        const title = norm(p.trackTitle ?? "");
        return ToplevelManager.toplevels.values.some(t => t.title.includes("YouTube") && (title === "" || norm(t.title).includes(title)));
    }
}
