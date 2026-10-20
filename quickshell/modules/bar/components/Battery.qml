import QtQuick
import Quickshell.Services.UPower
import qs.core
import qs.modules.widgets

// Battery level, on laptops only: yellow at 20%, red at 10% unless it's charging.
// Click for the control center.
Text {
    id: root
    anchors.verticalCenter: parent.verticalCenter

    readonly property var battery: UPower.displayDevice
    readonly property real level: {
        const p = battery?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged
    // battery-outline, battery-10 … battery-90 (consecutive codepoints), battery full
    readonly property string glyph: charging ? "\u{f0084}" : level >= 0.95 ? "\u{f0079}" : level < 0.05 ? "\u{f008e}" : String.fromCodePoint(0xf007a + Math.max(1, Math.min(9, Math.floor(level * 10))) - 1)

    visible: battery?.isLaptopBattery ?? false
    text: glyph + " " + Math.round(level * 100) + "%"
    color: charging ? Main.theme.colFg : level <= 0.1 ? Main.theme.colRed : level <= 0.2 ? Main.theme.colAmber : Main.theme.colFg
    font: Main.pillFont

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: ControlCenter.opened ? ControlCenter.hide() : ControlCenter.show()
    }
}
