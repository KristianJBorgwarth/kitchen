import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.core

// Now-playing card for one MPRIS player.
Rectangle {
    id: root
    required property MprisPlayer player

    implicitHeight: 84
    radius: 4
    color: Main.theme.colSurface

    // MPRIS doesn't push position updates; poke it while playing
    Timer {
        interval: 1000
        running: root.player?.isPlaying ?? false
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    ClippingRectangle {
        id: art
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 64
        radius: 4
        color: Main.theme.colMuted

        Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "󰎈"
            color: Main.theme.colAccentMid
            font: Main.iconFont
        }

        Image {
            id: cover
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 128
            sourceSize.height: 128
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.player?.trackTitle || root.player?.identity || ""
            color: Main.theme.colFg
            font: Main.barFont
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.player?.trackArtist || root.player?.identity || ""
            color: Main.theme.colAccentMid
            font: Main.smallFont
            elide: Text.ElideRight
        }

        Row {
            spacing: 2
            IconButton {
                implicitWidth: 28
                implicitHeight: 28
                icon: "󰒮"
                iconFont: Main.barFont
                opacity: root.player?.canGoPrevious ? 1 : 0.4
                onClicked: root.player?.previous()
            }
            IconButton {
                implicitWidth: 28
                implicitHeight: 28
                icon: root.player?.isPlaying ? "󰏤" : "󰐊"
                iconFont: Main.barFont
                onClicked: root.player?.togglePlaying()
            }
            IconButton {
                implicitWidth: 28
                implicitHeight: 28
                icon: "󰒭"
                iconFont: Main.barFont
                opacity: root.player?.canGoNext ? 1 : 0.4
                onClicked: root.player?.next()
            }
        }

        Rectangle {
            visible: root.player?.lengthSupported ?? false
            width: parent.width
            height: 3
            radius: 2
            color: Main.theme.colMuted

            Rectangle {
                width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                height: parent.height
                radius: 2
                color: Main.theme.colAccentLight
            }
        }
    }
}
