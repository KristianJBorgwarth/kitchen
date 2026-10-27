import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services
import "components"

// Popups in the bottom-right corner of the focused monitor, newest closest to the corner.
// Always mapped: with no popups the list is empty, so the input mask is too. A window per
// screen, made and dropped with it, so an unplug can't leave one closed.
Scope {
    id: root
    readonly property string screenName: (Main.screens.find(s => s.name === Compositor.focusedMonitor) ?? Main.screens[0])?.name ?? ""

    // ticks the "2m ago" labels
    property real now: Date.now()
    Timer {
        interval: 30000
        running: Notifs.popups.length > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Variants {
        model: Main.screens

        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            // the hidden ones keep their cards (and timeouts) for when focus moves there
            visible: modelData.name === root.screenName
            color: "transparent"
            anchors.bottom: true
            anchors.right: true
            margins.bottom: 12
            margins.right: 12
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-notifications"

            implicitWidth: 380
            implicitHeight: Math.max(1, list.contentHeight)
            mask: Region {
                item: list
            }

            ListView {
                id: list
                anchors.fill: parent
                interactive: false
                spacing: 10
                verticalLayoutDirection: ListView.BottomToTop
                model: ScriptModel {
                    // newest first, so it lands closest to the corner
                    values: Notifs.popups.slice(-5).reverse()
                }

                add: Transition {
                    NumberAnimation {
                        property: "x"
                        from: 420
                        duration: Main.anim * 3
                        easing.type: Easing.OutCubic
                    }
                }
                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Main.anim * 2
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Main.anim * 2
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: NotificationCard {
                    id: card
                    required property var modelData
                    width: list.width
                    notification: modelData
                    popup: true
                    now: root.now

                    // hovering keeps it up
                    Timer {
                        interval: Notifs.timeout(card.modelData)
                        running: interval > 0 && !card.hovered
                        onTriggered: Notifs.hidePopup(card.modelData)
                    }
                }
            }
        }
    }
}
