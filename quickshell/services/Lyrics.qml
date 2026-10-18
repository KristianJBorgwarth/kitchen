pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics — synced lyrics from lrclib.net for the given track. Off by default since it
// sends artist/title to lrclib; the toggle is remembered across restarts.
Singleton {
    id: root
    readonly property bool enabled: settings.lyrics

    // "off", "loading", "synced", "plain", "none"
    property string status: "off"
    property var lines: [] // [{time (s, -1 when unsynced), text}]

    property string _key: ""
    property var _cache: ({})

    function setEnabled(on: bool): void {
        settings.lyrics = on;
    }

    FileView {
        // the file only exists once a setting has been changed
        printErrors: false
        path: Quickshell.statePath("music.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property bool lyrics: false
        }
    }

    function parse(entry) {
        if (entry?.syncedLyrics) {
            const out = [];
            for (const l of entry.syncedLyrics.split("\n")) {
                const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s?(.*)$/);
                if (m)
                    out.push({ time: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3] });
            }
            if (out.length > 0)
                return { status: "synced", lines: out };
        }
        if (entry?.plainLyrics)
            return { status: "plain", lines: entry.plainLyrics.split("\n").map(text => ({ time: -1, text })) };
        return { status: "none", lines: [] };
    }

    function apply(key, result) {
        _cache[key] = result;
        if (key !== _key)
            return;
        status = result.status;
        lines = result.lines;
    }

    function get(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            done(body);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // exact match first (artist + title + duration), then a fuzzy search
    function load(title: string, artist: string, album: string, length: real): void {
        if (!enabled || !title) {
            _key = "";
            status = enabled ? "none" : "off";
            lines = [];
            return;
        }
        const key = artist + "\u0000" + title;
        if (key === _key)
            return;
        _key = key;
        if (_cache[key]) {
            apply(key, _cache[key]);
            return;
        }
        status = "loading";
        lines = [];
        const q = s => encodeURIComponent(s);
        let url = "https://lrclib.net/api/get?track_name=" + q(title) + "&artist_name=" + q(artist);
        if (album)
            url += "&album_name=" + q(album);
        if (length > 0)
            url += "&duration=" + Math.round(length);
        get(url, exact => {
            const r = parse(exact);
            if (r.status !== "none")
                return apply(key, r);
            get("https://lrclib.net/api/search?q=" + q(artist + " " + title), results => {
                const list = Array.isArray(results) ? results : [];
                apply(key, parse(list.find(e => e.syncedLyrics) ?? list[0]));
            });
        });
    }

    onEnabledChanged: {
        _key = "";
        if (!enabled) {
            status = "off";
            lines = [];
        }
    }
}
