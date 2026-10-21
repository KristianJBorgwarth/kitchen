import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// Output volume as a speaker that follows the level. Resting on it slides a level bar out to
// its left; scroll changes the volume, click mutes, right click opens the sound tab.
Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: Audio.sink !== null

    readonly property real volume: Audio.sink?.audio?.volume ?? 0
    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    readonly property string glyph: muted || volume === 0 ? "\u{f075f}" : volume < 0.34 ? "\u{f057f}" : volume < 0.67 ? "\u{f0580}" : "\u{f057e}"

    readonly property int barWidth: 72
    readonly property int gap: 10
    property bool expanded: false

    HoverHandler {
        id: hover
    }

    // opens only once the mouse rests on it, so passing over on the way to the tray doesn't
    // push the bar around; closes after a short grace period
    Timer {
        interval: 150
        running: !root.expanded && hover.hovered
        onTriggered: root.expanded = true
    }
    Timer {
        interval: 400
        running: root.expanded && !hover.hovered
        onTriggered: root.expanded = false
    }

    Row {
        id: row

        // the gap to the speaker is part of the drawer, so it opens with it instead of popping
        Item {
            id: drawer
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            width: root.expanded ? root.barWidth + root.gap : 0
            opacity: root.expanded ? 1 : 0
            visible: width > 0
            clip: true

            // out with a soft landing, back in a little quicker
            Behavior on width {
                NumberAnimation {
                    duration: root.expanded ? 220 : 160
                    easing.type: root.expanded ? Easing.OutCubic : Easing.InCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.expanded ? 220 : 120
                }
            }

            // full length from the start, pinned to the speaker, so the bar is revealed
            // rather than squeezed
            Item {
                anchors.right: parent.right
                anchors.rightMargin: root.gap
                width: root.barWidth
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Main.theme.overlay(0.15)
                }
                Rectangle {
                    height: parent.height
                    width: parent.width * Math.min(1, root.volume)
                    radius: height / 2
                    color: root.muted ? Main.theme.colAccentMid : Main.theme.colFg

                    Behavior on width {
                        NumberAnimation {
                            duration: Main.anim * 2
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.muted ? Main.theme.colAccentMid : Main.theme.colFg
            font: Main.pillFont
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                ControlCenter.openTab("sound");
                if (!ControlCenter.opened)
                    ControlCenter.show();
            } else {
                Audio.toggleMute(Audio.sink);
            }
        }
        // scrolling is a clear intent, so it opens the bar straight away
        onWheel: wheel => {
            root.expanded = true;
            Audio.setVolume(Audio.sink, root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
        }
    }
}
