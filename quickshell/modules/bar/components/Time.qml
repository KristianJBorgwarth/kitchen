pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// your singletons should always have Singleton as the type
Singleton {
    id: root
    property string time
    property string date_format: regular
    property string regular: "+%H:%M"
    property string long: "+%Y %b, %a - %H:%M:%S"

    Process {
        id: dateProc
        command: ["date", root.date_format]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.time = this.text
        }
    }

    Timer {
        interval: 10
        running: true
        repeat: true
        onTriggered: dateProc.running = true
    }
}
