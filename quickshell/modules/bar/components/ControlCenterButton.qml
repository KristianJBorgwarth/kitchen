import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

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
        // silent shows the crossed bell; otherwise a bell with the count while there's history
        Text {
            id: bell
            visible: Dnd.enabled || Notifs.count > 0
            text: (Dnd.enabled ? "󰂛" : "󰂚") + (Notifs.count > 0 ? " " + Notifs.count : "")
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

    // the bell opens straight on the notifications tab
    MouseArea {
        x: bell.x
        width: bell.visible ? bell.width : 0
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            ControlCenter.openTab("notifications");
            if (!ControlCenter.opened)
                ControlCenter.show();
        }
    }
}
