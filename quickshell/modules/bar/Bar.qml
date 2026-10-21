import Quickshell // for PanelWindow
import Quickshell.I3
import Quickshell.Wayland
import QtQuick // for Text
import qs.core
import qs.services
import qs.modules.widgets
import "components"

// A bar on every monitor. The leftmost one (workspace 1's in the sway config) is the main
// bar with everything; the others show their own workspaces, and the focused app while
// focus is on them.
Scope {
    id: root
    readonly property var mainScreen: Quickshell.screens.reduce((a, s) => !a || s.x < a.x ? s : a, null)

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            readonly property bool main: modelData === root.mainScreen

            anchors.top: true
            anchors.left: true
            anchors.right: true
            // the pills plus the gap above them; the gap below is sway's own window gap
            implicitHeight: 34
            color: "transparent"

            // space between the pills, and between them and the screen edges
            readonly property int gap: 8

            // the main bar is always mapped, so it hosts the inhibitor for Awake
            IdleInhibitor {
                window: barWindow
                enabled: barWindow.main && Awake.enabled
            }

            BarPill {
                id: leftPill
                anchors.left: parent.left
                anchors.leftMargin: barWindow.gap
                Workspaces {
                    screen: barWindow.modelData
                }
            }

            // focused app, or what's running in a focused terminal; on the focused monitor's bar
            BarPill {
                anchors.left: leftPill.right
                anchors.leftMargin: barWindow.gap
                shown: Focus.toplevel !== null && I3.focusedMonitor?.name === barWindow.modelData.name
                ActiveApp {}
            }

            // only made on the main bar: the tray and others register themselves as the anchor
            // for their popups, so a second copy would steal that
            Loader {
                anchors.fill: parent
                active: barWindow.main
                sourceComponent: Item {
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
                        anchors.right: rightPill.left
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
                        Battery {}
                        Volume {}
                        Tray {}
                        PowerMenu {}
                    }
                }
            }
        }
    }
}
