pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Silent mode: notification popups are held back (critical ones still show) but
// everything still lands in the history. Remembered across restarts.
Singleton {
    id: root
    readonly property bool enabled: settings.silent

    function toggle(): void {
        settings.silent = !settings.silent;
    }

    FileView {
        // the file only exists once a setting has been changed
        printErrors: false
        path: Quickshell.statePath("notifications.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property bool silent: false
        }
    }
}
