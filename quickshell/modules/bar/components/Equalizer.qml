import QtQuick
import qs.core
import qs.services

// Mirrored spectrum bars fed by Cava. Without cava installed it fakes a
// gentle wave while playing; when paused the bars settle into dots.
Item {
    id: root
    property bool playing: false
    property real barWidth: 3
    property real gap: 2
    property real maxHeight: 16

    implicitWidth: Cava.count * barWidth + (Cava.count - 1) * gap
    implicitHeight: maxHeight

    property var fake: new Array(Cava.count).fill(0)
    property real phase: 0

    Timer {
        interval: 60
        running: root.playing && !Cava.available
        repeat: true
        onTriggered: {
            root.phase += 0.35;
            const out = new Array(Cava.count);
            for (let i = 0; i < Cava.count; i++)
                out[i] = 0.35 + 0.3 * Math.sin(root.phase + i * 0.7) + 0.25 * Math.sin(root.phase * 1.7 - i * 1.3) * Math.random();
            root.fake = out;
        }
    }

    readonly property var levels: !root.playing ? new Array(Cava.count).fill(0) : Cava.available ? Cava.bars : fake

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: Cava.count

            Rectangle {
                required property int index
                readonly property real level: Math.max(0, Math.min(1, root.levels[index] ?? 0))

                anchors.verticalCenter: parent.verticalCenter
                width: root.barWidth
                height: Math.max(root.barWidth, level * root.maxHeight)
                radius: root.barWidth / 2
                // louder bars burn brighter
                color: Qt.rgba(Main.theme.colFg.r, Main.theme.colFg.g, Main.theme.colFg.b, 0.45 + 0.55 * level)

                Behavior on height {
                    NumberAnimation {
                        duration: 70
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
