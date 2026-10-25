import QtQuick
import qs.core
import qs.services

// Connection status: wired, Wi-Fi with its signal strength, or disconnected. Resting on it slides
// out the network name. Display only.
Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property real signal: Network.activeDevice?.networks.values.find(n => n.connected)?.signalStrength ?? 0
    readonly property string glyph: {
        if (Network.wired)
            return "󰈀";
        if (!Network.hasWifi)
            return "󰖪";
        if (!Network.wifiEnabled)
            return "󰤭";
        if (!Network.connected)
            return "󰤮";
        return signal > 0.75 ? "󰤨" : signal > 0.5 ? "󰤥" : signal > 0.25 ? "󰤢" : "󰤟";
    }
    readonly property color tint: Network.connected ? Main.theme.colFg : Main.theme.colAccentDark

    HoverHandler {
        id: hover
    }

    Row {
        id: row

        BarDrawer {
            hovered: hover.hovered

            Text {
                text: Network.label
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
