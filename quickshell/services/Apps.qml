pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // desktop entry for a program or app id: ids like com.mitchellh.ghostty or brave-browser
    // don't match a plain heuristic lookup, so also check ids and Exec lines
    function findEntry(prog) {
        if (!prog)
            return null;
        const p = prog.toLowerCase();
        const apps = DesktopEntries.applications.values;
        const id = e => e.id.toLowerCase();
        const exec = e => (e.execString ?? "").split(/\s+/)[0].split("/").pop();
        // strictest match wins, so thunar beats thunar-settings
        return apps.find(e => id(e) === p) ?? apps.find(e => id(e).endsWith("." + p)) ?? apps.find(e => exec(e) === prog && !e.noDisplay) ?? apps.find(e => id(e).startsWith(p + "-")) ?? DesktopEntries.heuristicLookup(prog);
    }

    function icon(prog) {
        return findEntry(prog)?.icon ?? "";
    }
}
