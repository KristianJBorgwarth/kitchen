import QtQuick
import Quickshell
import Quickshell.Io

// The palette, read from theme/<name>.json: the one place colors are defined. ThemeExport
// writes the other apps' colors (ghostty, sway, k9s) from the same file.
Scope {
    id: root
    property string name: "dark"
    readonly property var palette: {
        try {
            return JSON.parse(file.text());
        } catch (e) {
            return {};
        }
    }

    // loaded before first paint, so nothing flashes in fallback colors
    FileView {
        id: file
        path: Quickshell.shellPath("theme/" + root.name + ".json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property color colBg: palette.bg ?? "#141414"
    readonly property color colSurface: palette.surface ?? "#1e1e1e"
    readonly property color colFg: palette.fg ?? "#e8e8e8"
    readonly property color colMuted: palette.muted ?? "#3a3a3a"
    readonly property color colAccentDark: palette.dim ?? "#5a5a5a"
    readonly property color colAccentMid: palette.mid ?? "#808080"
    readonly property color colAccentLight: palette.light ?? "#aaaaaa"
    readonly property color colBlue: palette.blue ?? "#5f87af"
    readonly property color colViolet: palette.violet ?? "#8787af"
    readonly property color colAmber: palette.amber ?? "#d7af5f"
    readonly property color colGreen: palette.green ?? "#87af5f"
    readonly property color colRed: palette.red ?? "#d75f5f"
    readonly property color colTeal: palette.teal ?? "#5f9f9f"
}
