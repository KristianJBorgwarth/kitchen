import QtQuick
import qs.core

Item {
    id: root
    property color accent: Main.theme.colBlue
    property date today: new Date()
    property int offset: 0 // months from the current one

    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)

    function shift(d) {
        offset += d;
    }

    readonly property var days: {
        const y = shown.getFullYear(), m = shown.getMonth();
        const lead = (new Date(y, m, 1).getDay() + 6) % 7; // monday-based
        const count = new Date(y, m + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(y, m, i - lead + 1);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === m,
                isToday: d.toDateString() === root.today.toDateString(),
                weekend: d.getDay() === 0 || d.getDay() === 6
            });
        }
        return out.slice(35).every(c => !c.inMonth) ? out.slice(0, 35) : out;
    }

    // midnight rollover keeps "today" right if the shell runs for days
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    Item {
        id: head
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.shown.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            color: Main.theme.colFg
            font.family: Main.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: [
                    { icon: "󰅁", d: -1 },
                    { icon: "󰃭", d: 0 },
                    { icon: "󰅂", d: 1 }
                ]
                IconButton {
                    required property var modelData
                    implicitWidth: 24
                    implicitHeight: 22
                    icon: modelData.icon
                    iconFont: Main.smallFont
                    visible: modelData.d !== 0 || root.offset !== 0
                    onClicked: modelData.d === 0 ? root.offset = 0 : root.shift(modelData.d)
                }
            }
        }
    }

    Grid {
        id: grid
        anchors.top: head.bottom
        anchors.topMargin: 8
        width: parent.width
        columns: 7
        readonly property real cell: width / 7
        readonly property real rowH: Math.min(28, (root.height - head.height - 8) / (root.days.length / 7 + 1))

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
                required property string modelData
                width: grid.cell
                height: grid.rowH
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Main.theme.colAccentDark
                font: Main.smallFont
            }
        }

        Repeater {
            model: root.days
            Item {
                required property var modelData
                width: grid.cell
                height: grid.rowH

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    color: parent.modelData.isToday ? root.accent : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.day
                    color: parent.modelData.isToday ? Main.theme.colBg : !parent.modelData.inMonth ? Main.theme.colMuted : parent.modelData.weekend ? Main.theme.colAccentMid : Main.theme.colFg
                    font.family: Main.fontFamily
                    font.pixelSize: 12
                    font.weight: parent.modelData.isToday ? Font.DemiBold : Font.Normal
                }
            }
        }
    }
}
