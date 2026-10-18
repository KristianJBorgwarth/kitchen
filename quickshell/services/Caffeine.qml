pragma Singleton

import QtQuick
import Quickshell

// Caffeine — idle inhibit flag; the IdleInhibitor itself lives on the bar window
Singleton {
    property bool enabled: false
}
