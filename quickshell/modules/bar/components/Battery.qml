import QtQuick
import Quickshell.Services.UPower
import qs.core
import qs.modules.widgets

// Battery level, on laptops only: yellow at 20%, red at 10% unless it's charging. Resting on
// it slides out the percentage and the time left (or until full). Display only.
Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: battery?.isLaptopBattery ?? false

    readonly property var battery: UPower.displayDevice
    readonly property real level: {
        const p = battery?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged
    // battery-outline, battery-10 … battery-90 (consecutive codepoints), battery full
    readonly property string glyph: charging ? "\u{f0084}" : level >= 0.95 ? "\u{f0079}" : level < 0.05 ? "\u{f008e}" : String.fromCodePoint(0xf007a + Math.max(1, Math.min(9, Math.floor(level * 10))) - 1)
    readonly property color tint: charging ? Main.theme.colFg : level <= 0.1 ? Main.theme.colRed : level <= 0.2 ? Main.theme.colAmber : Main.theme.colFg

    // "2h 14m left" / "full in 40m"; empty while UPower is still estimating
    readonly property string timeLeft: {
        const s = charging ? (battery?.timeToFull ?? 0) : (battery?.timeToEmpty ?? 0);
        if (s <= 0 || battery?.state === UPowerDeviceState.FullyCharged)
            return "";
        const h = Math.floor(s / 3600);
        const m = Math.round(s % 3600 / 60);
        const t = (h > 0 ? h + "h " : "") + m + "m";
        return charging ? "full in " + t : t + " left";
    }

    HoverHandler {
        id: hover
    }

    Row {
        id: row

        BarDrawer {
            hovered: hover.hovered

            Text {
                text: Math.round(root.level * 100) + "%" + (root.timeLeft ? "  ·  " + root.timeLeft : "")
                color: root.tint
                font: Main.pillFont
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.tint
            font: Main.pillFont

            HoverChip {}
        }
    }
}
