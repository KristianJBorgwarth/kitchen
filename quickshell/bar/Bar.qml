import Quickshell // for PanelWindow
import Quickshell.I3
import QtQuick // for Text
import qs.core
import "modules"

Scope {
    id: root
    PanelWindow {
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 20
        color: Main.theme.colBg

        Workspaces {
            anchors.fill: parent
            anchors.leftMargin: 8
        }
        Clock {
            anchors.centerIn: parent
        }
    }
}
