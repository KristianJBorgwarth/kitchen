import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property var player: Media.player

    Row {
        id: row
        spacing: 10

        Equalizer {
            anchors.verticalCenter: parent.verticalCenter
            playing: root.player?.isPlaying ?? false
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 200)
            text: {
                const t = root.player?.trackTitle || root.player?.identity || "";
                const a = root.player?.trackArtist ?? "";
                return a ? t + " — " + a : t;
            }
            color: root.player?.isPlaying ? Main.theme.colFg : Main.theme.colAccentMid
            font: Main.pillFont
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.player?.togglePlaying();
            else
                MusicPlayer.toggle();
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.player?.previous();
            else
                root.player?.next();
        }
    }
}
