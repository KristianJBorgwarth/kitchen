import QtQuick
import Quickshell.Services.Pipewire
import qs.core

// Red while an app is recording: the mic, a webcam, or the screen (a portal screen share).
// Read off the PipeWire graph, so it's anything linked to a capture device, not monitor
// captures of the speakers (cava). Apps that open a webcam directly, not via PipeWire,
// don't show up.
Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10

    readonly property var capturing: Pipewire.linkGroups.values.map(g => g.source).filter(n => n)
    readonly property var videoNames: capturing.filter(n => n.type === PwNodeType.VideoSource).map(n => n.name)
    readonly property bool mic: capturing.some(n => n.type === PwNodeType.AudioSource)
    readonly property bool camera: videoNames.some(name => name.startsWith("v4l2_") || name.startsWith("libcamera"))
    readonly property bool screen: videoNames.some(name => !name.startsWith("v4l2_") && !name.startsWith("libcamera"))

    visible: mic || camera || screen

    Text {
        visible: parent.mic
        text: "\u{f036c}"
        color: Main.theme.colRed
        font: Main.pillFont
    }
    Text {
        visible: parent.camera
        text: "\u{f05a0}"
        color: Main.theme.colRed
        font: Main.pillFont
    }
    Text {
        visible: parent.screen
        text: "\u{f1483}"
        color: Main.theme.colRed
        font: Main.pillFont
    }
}
