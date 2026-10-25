import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// Time left on the running or paused timer / alarm.
// Click opens the panel, middle click starts/pauses, right click resets.
Text {
    anchors.verticalCenter: parent.verticalCenter

    text: "󰀠 " + Alarm.fmt(Alarm.remainingMs)
    opacity: Alarm.running ? 1 : 0.55
    color: Main.theme.colFg
    font: Main.pillFont

    HoverChip {}

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                Alarm.toggle();
            else if (mouse.button === Qt.RightButton)
                Alarm.reset();
            else
                AlarmPanel.toggle();
        }
    }
}
