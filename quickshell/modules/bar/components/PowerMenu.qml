import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// The power button: a click slides the session actions out to its left. The ones that end the
// session arm on the first click (red, with a "?" label) and fire on a second within 3s.
// It folds back in a moment after the mouse leaves.
Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property bool expanded: false
    // the slide is slower than Main.anim so it reads as motion, not a jump
    readonly property int slide: Main.anim * 4

    readonly property var actions: [
        { icon: "󰌾", label: "lock", confirm: false, run: () => Lock.lock() },
        { icon: "󰤄", label: "sleep", confirm: false, run: () => Lock.suspend() },
        { icon: "󰍃", label: "log out", confirm: true, run: () => Session.logout() },
        { icon: "󰜉", label: "reboot", confirm: true, run: () => Session.reboot() },
        { icon: "󰐥", label: "power off", confirm: true, run: () => Session.poweroff() }
    ]
    property int armed: -1

    onExpandedChanged: armed = -1

    HoverHandler {
        id: hover
    }

    Timer {
        interval: 1500
        running: root.expanded && !hover.hovered
        onTriggered: root.expanded = false
    }
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = -1
    }

    Row {
        id: row
        spacing: 12

        Item {
            id: drawer
            anchors.verticalCenter: parent.verticalCenter
            height: items.implicitHeight
            width: root.expanded ? items.implicitWidth : 0
            opacity: root.expanded ? 1 : 0
            visible: width > 0
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: root.slide
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.slide
                }
            }

            // pinned to the right edge, so the actions slide in from behind the button
            Row {
                id: items
                anchors.right: parent.right
                spacing: 12

                Repeater {
                    model: root.actions
                    Text {
                        id: action
                        required property var modelData
                        required property int index
                        readonly property bool isArmed: root.armed === index
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon + (isArmed ? " " + modelData.label + "?" : "")
                        color: isArmed ? Main.theme.colRed : actionMouse.containsMouse ? Main.theme.colFg : Main.theme.colAccentLight
                        font: Main.barFont

                        Behavior on color {
                            ColorAnimation {
                                duration: Main.anim
                            }
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (action.modelData.confirm && !action.isArmed) {
                                    root.armed = action.index;
                                    disarm.restart();
                                    return;
                                }
                                root.expanded = false;
                                action.modelData.run();
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.expanded ? "󰅖" : "󰐥"
            color: root.expanded ? Main.theme.colAccentLight : Main.theme.colFg
            font: Main.barFont

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
