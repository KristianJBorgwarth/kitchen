import Quickshell // for PanelWindow
import Quickshell.Wayland
import QtQuick // for Text
import qs.core
import qs.services
import qs.modules.widgets
import "components"

// One bar, on the leftmost monitor (workspace 1's in hypr/conf/workspaces.lua)
Scope {
    id: root
    readonly property var mainScreen: Quickshell.screens.reduce((a, s) => !a || s.x < a.x ? s : a, null)

    PanelWindow {
        id: barWindow
        screen: root.mainScreen
        anchors.top: true
        anchors.left: true
        anchors.right: true
        // the pills plus the gap above them; the gap below is Hyprland's own window gap
        implicitHeight: 34
        color: "transparent"

        // space between the pills, and between them and the screen edges
        readonly property int gap: 8

        // the bar is always mapped, so it hosts the inhibitor for Awake
        IdleInhibitor {
            window: barWindow
            enabled: Awake.enabled
        }

        BarPill {
            id: leftPill
            anchors.left: parent.left
            anchors.leftMargin: barWindow.gap
            Workspaces {}
        }

        // focused app, or what's running in a focused terminal
        BarPill {
            anchors.left: leftPill.right
            anchors.leftMargin: barWindow.gap
            shown: Focus.toplevel !== null
            ActiveApp {}
        }

        BarPill {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            Clock {}
        }

        BarPill {
            anchors.left: centerPill.right
            anchors.leftMargin: barWindow.gap
            shown: Media.player !== null
            NowPlaying {}
        }

        BarPill {
            id: pomodoroPill
            anchors.right: rightPill.left
            anchors.rightMargin: barWindow.gap
            shown: Pomodoro.active
            PomodoroTimer {}
        }

        BarPill {
            anchors.right: pomodoroPill.visible ? pomodoroPill.left : rightPill.left
            anchors.rightMargin: barWindow.gap
            // only while there are notifications; silent mode is in the control center too
            shown: Notifs.count > 0
            Notifications {}
        }

        BarPill {
            id: rightPill
            anchors.right: parent.right
            anchors.rightMargin: barWindow.gap
            spacing: 20
            Privacy {}
            AwakeIndicator {}
            Internet {}
            Battery {}
            PowerMenu {}
        }
    }
}
