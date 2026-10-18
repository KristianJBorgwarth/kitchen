import QtQuick
import qs.core
import qs.services

// Without cava it fakes a music-shaped wave (heavier lows) so the panel still moves.
Item {
    id: root
    property bool playing: false
    property real gap: 4
    // share of the height above the baseline; the rest is reflection
    property real split: 0.72

    readonly property int count: Cava.count
    readonly property real barW: (width - gap * (count - 1)) / count
    readonly property real baseY: height * split

    property var fake: new Array(count).fill(0)
    property real phase: 0

    Timer {
        interval: 50
        running: root.playing && !Cava.available
        repeat: true
        onTriggered: {
            root.phase += 0.22;
            const out = new Array(root.count);
            for (let i = 0; i < root.count; i++) {
                const x = i / root.count;
                const envelope = 0.85 - 0.55 * x;
                const wave = 0.5 + 0.3 * Math.sin(root.phase + x * 9) + 0.2 * Math.sin(root.phase * 2.3 - x * 23);
                out[i] = Math.max(0.04, envelope * wave * (0.75 + 0.25 * Math.random()));
            }
            root.fake = out;
        }
    }

    readonly property var levels: !playing ? new Array(count).fill(0) : Cava.available ? Cava.bars : fake

    Rectangle {
        y: root.baseY
        width: parent.width
        height: 1
        color: Main.theme.overlay(0.06)
    }

    Repeater {
        model: root.count

        Item {
            id: bar
            required property int index
            readonly property real level: Math.max(0, Math.min(1, root.levels[index] ?? 0))
            x: index * (root.barW + root.gap)
            width: root.barW
            height: root.height

            Rectangle {
                id: up
                y: root.baseY - height
                width: parent.width
                height: Math.max(2, bar.level * (root.baseY - 2))
                radius: Math.min(width, 6) / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Main.theme.colFg
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(Main.theme.colFg.r, Main.theme.colFg.g, Main.theme.colFg.b, 0.35)
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Rectangle {
                y: root.baseY + 2
                width: parent.width
                height: up.height * (1 - root.split) / root.split
                radius: up.radius
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Main.theme.overlay(0.14)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }
        }
    }
}
