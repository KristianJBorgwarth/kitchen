pragma Singleton

import QtQuick
import Quickshell

// Awake — "stay awake" (idle inhibit) flag; the IdleInhibitor itself lives on the bar window
Singleton {
    property bool enabled: false
}
