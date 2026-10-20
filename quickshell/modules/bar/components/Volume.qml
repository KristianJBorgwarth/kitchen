import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// Output volume: scroll to change, click to mute, right click for the sound tab.
Text {
    id: root
    anchors.verticalCenter: parent.verticalCenter

    readonly property real volume: Audio.sink?.audio?.volume ?? 0
    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    readonly property string glyph: muted || volume === 0 ? "\u{f075f}" : volume < 0.34 ? "\u{f057f}" : volume < 0.67 ? "\u{f0580}" : "\u{f057e}"

    visible: Audio.sink !== null
    text: glyph + " " + Math.round(volume * 100) + "%"
    color: muted ? Main.theme.colAccentMid : Main.theme.colFg
    font: Main.barFont

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
        onWheel: wheel => Audio.setVolume(Audio.sink, root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
