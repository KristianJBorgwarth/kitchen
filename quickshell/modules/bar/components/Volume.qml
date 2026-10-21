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

    HoverHandler {
        id: hover
    }

    Row {
        id: row

        BarDrawer {
            id: drawer
            hovered: hover.hovered

            Item {
                width: 72
                height: 4

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

            HoverChip {}
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
            drawer.open = true;
            Audio.setVolume(Audio.sink, root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
        }
    }
}
