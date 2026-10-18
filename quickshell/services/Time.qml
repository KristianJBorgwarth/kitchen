pragma Singleton

import Quickshell
import QtQuick

// your singletons should always have Singleton as the type
Singleton {
    id: root
    // formatted in-process: spawning `date` on a timer forks constantly (expensive under EDR/AV)
    readonly property string time: Qt.formatDateTime(clock.date, date_format)
    property string date_format: regular
    property string regular: "HH:mm"
    property string verbose: "ddd d MMM yyyy - HH:mm:ss"

    SystemClock {
        id: clock
        // only tick every second when seconds are shown
        precision: root.date_format === root.verbose ? SystemClock.Seconds : SystemClock.Minutes
    }
}
