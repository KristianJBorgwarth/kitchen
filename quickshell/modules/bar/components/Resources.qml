import Quickshell
import QtQuick
import qs.core
import qs.services

Row {
    Text {
        text: " " + Cpu.cpuUsage + "%"
        color: Main.theme.colFg
        font {
            family: Main.fontFamily
            pixelSize: 14
        }
    }
    Text {

    }
}
