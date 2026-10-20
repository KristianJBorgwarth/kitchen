import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// The bell with the count, on the bar only while there's history; crossed out while silent.
// Click for the notifications tab, right click to toggle silent.
Text {
    id: root
    anchors.verticalCenter: parent.verticalCenter

    readonly property bool showing: ControlCenter.opened && ControlCenter.tab === "notifications"

    text: (Dnd.enabled ? "󰂛" : "󰂚") + " " + Notifs.count
    color: showing ? Main.theme.colAccentLight : Main.theme.colFg
    font: Main.pillFont

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Dnd.toggle();
            } else if (root.showing) {
                ControlCenter.hide();
            } else {
                ControlCenter.openTab("notifications");
                if (!ControlCenter.opened)
                    ControlCenter.show();
            }
        }
    }
}
