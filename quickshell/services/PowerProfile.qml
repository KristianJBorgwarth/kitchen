pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
// qualified: its PowerProfile type would shadow this singleton's name
import Quickshell.Services.UPower as UP

// PowerProfile — power-profiles-daemon (or tuned-ppd) over D-Bus via Quickshell's UPower
// module: change notifications instead of polling powerprofilesctl (a python process).
Singleton {
    id: root
    // the daemon ships one of these D-Bus service files; checking them needs no process
    readonly property bool available: ppdService.loaded || upowerPpdService.loaded
    // check `available` first: touching UP.PowerProfiles without the daemon logs a warning
    readonly property var profiles: available && UP.PowerProfiles.hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]
    readonly property string current: available ? ({
            [UP.PowerProfile.PowerSaver]: "power-saver",
            [UP.PowerProfile.Balanced]: "balanced",
            [UP.PowerProfile.Performance]: "performance"
        })[UP.PowerProfiles.profile] ?? "" : ""

    FileView {
        id: ppdService
        path: "/usr/share/dbus-1/system-services/net.hadess.PowerProfiles.service"
        printErrors: false
    }
    FileView {
        id: upowerPpdService
        path: "/usr/share/dbus-1/system-services/org.freedesktop.UPower.PowerProfiles.service"
        printErrors: false
    }

    function set(profile: string): void {
        const p = { "power-saver": UP.PowerProfile.PowerSaver, "balanced": UP.PowerProfile.Balanced, "performance": UP.PowerProfile.Performance }[profile];
        if (available && p !== undefined)
            UP.PowerProfiles.profile = p;
    }
}
