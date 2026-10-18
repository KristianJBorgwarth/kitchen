import Quickshell // for PanelWindow
import Quickshell.I3
import Quickshell.Wayland
import QtQuick // for Text
import qs.core
import qs.services
import qs.modules.widgets
import "components"

Scope {
    id: root
    PanelWindow {
        id: barWindow
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 30
        color: "transparent"

        // the bar is always mapped, so it hosts the inhibitor for Awake
        IdleInhibitor {
            window: barWindow
            enabled: Awake.enabled
        }

        Rectangle {
            id: leftPill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            radius: 4
            color: Main.theme.colBg
            height: 25
            width: leftRow.implicitWidth + 16

            Row {
                id: leftRow
                anchors.centerIn: parent
                spacing: 4
                Workspaces {}
            }
        }

        Rectangle {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: Main.theme.colBg
            height: 25
            width: centerRow.implicitWidth + 16

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 8
                Clock {}
            }
        }

        Rectangle {
            id: musicPill
            anchors.left: centerPill.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: Main.theme.colBg
            height: 25
            width: nowPlaying.implicitWidth + 20
            clip: true

            readonly property bool shown: Media.player !== null
            visible: opacity > 0
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.8

            Behavior on opacity {
                NumberAnimation {
                    duration: Main.anim
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Main.anim
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Main.anim
                    easing.type: Easing.OutCubic
                }
            }

            NowPlaying {
                id: nowPlaying
                anchors.centerIn: parent
            }
        }

        Rectangle {
            id: rightPill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            radius: 4
            color: Main.theme.colBg
            height: 25
            width: rightRow.implicitWidth + 16

            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: 20
                Resources {}
                Tray {}
                ControlCenterButton {}
            }
        }
    }
}
