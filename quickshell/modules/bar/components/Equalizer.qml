import QtQuick
import qs.core
import qs.services

// Spectrum bars from Cava resampled to `count`; fakes a wave when cava isn't installed.
Item {
    id: root
    property int count: 14
    property bool playing: false
    property real barWidth: 3
    property real gap: 2
    property real maxHeight: 16

    implicitWidth: count * barWidth + (count - 1) * gap
    implicitHeight: maxHeight

    property var fake: new Array(count).fill(0)
    property real phase: 0

    Timer {
        interval: 60
        running: root.playing && !Cava.available
        repeat: true
        onTriggered: {
            root.phase += 0.35;
            const out = new Array(root.count);
            for (let i = 0; i < root.count; i++)
                out[i] = 0.35 + 0.3 * Math.sin(root.phase + i * 0.7) + 0.25 * Math.sin(root.phase * 1.7 - i * 1.3) * Math.random();
            root.fake = out;
        }
    }

    function resample(src) {
        const out = new Array(count);
        for (let i = 0; i < count; i++) {
            const a = Math.floor(i * src.length / count);
            const b = Math.max(a + 1, Math.floor((i + 1) * src.length / count));
            let sum = 0;
            for (let j = a; j < b; j++)
                sum += src[j] ?? 0;
            out[i] = sum / (b - a);
        }
        return out;
    }

    readonly property var levels: !playing ? new Array(count).fill(0) : Cava.available ? resample(Cava.bars) : fake

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.count

            Rectangle {
                required property int index
                readonly property real level: Math.max(0, Math.min(1, root.levels[index] ?? 0))

                anchors.verticalCenter: parent.verticalCenter
                width: root.barWidth
                height: Math.max(root.barWidth, level * root.maxHeight)
                radius: root.barWidth / 2
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
