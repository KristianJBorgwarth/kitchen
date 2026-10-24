import QtQuick
import Quickshell
import Quickshell.Io

// The palette, read from theme/<name>.json: the one place colors are defined. ThemeExport
// writes the other apps' colors (ghostty, hyprland, k9s) from the same file.
Scope {
    id: root
    // fixed: always that palette (the lock screen stays dark). Otherwise the saved mode.
    property string fixed: ""
    readonly property string name: fixed || settings.mode
    readonly property bool dark: name === "dark"

    function toggle(): void {
        settings.mode = dark ? "light" : "dark";
    }

    FileView {
        printErrors: false
        path: Quickshell.statePath("theme.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property string mode: "dark"
        }
    }
    // both loaded up front: re-pointing one file at the other palette lagged a switch behind
    readonly property var palette: dark ? darkPalette : lightPalette
    readonly property var darkPalette: parse(darkFile.text())
    readonly property var lightPalette: parse(lightFile.text())

    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return {};
        }
    }

    // loaded before first paint, so nothing flashes in fallback colors
    FileView {
        id: darkFile
        path: Quickshell.shellPath("theme/dark.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    FileView {
        id: lightFile
        path: Quickshell.shellPath("theme/light.json")
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
    // the tint for hovers, borders and tracks: white on dark, black on light
    readonly property color colOverlay: palette.overlay ?? "#ffffff"

    function overlay(alpha) {
        return Qt.rgba(colOverlay.r, colOverlay.g, colOverlay.b, alpha);
    }
}
