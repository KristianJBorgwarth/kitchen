import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// Opens the control center; stay-awake/silent icons show next to it while on.
Item {
    id: root
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: icons.implicitWidth
    implicitHeight: icons.implicitHeight

    Row {
        id: icons
        spacing: 8

        Text {
            visible: Awake.enabled
            text: "󰈈"
            color: Main.theme.colFg
            font: Main.barFont
        }
        Text {
            visible: Dnd.enabled
            text: "󰂛"
            color: Main.theme.colFg
            font: Main.barFont
        }
        Text {
            text: "󰒓"
            color: ControlCenter.opened ? Main.theme.colAccentLight : Main.theme.colFg
            font: Main.barFont
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ControlCenter.toggle()
        onWheel: wheel => Audio.setVolume(Audio.sink, (Audio.sink?.audio?.volume ?? 0) + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
