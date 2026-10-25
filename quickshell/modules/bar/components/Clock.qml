// ClockWidget.qml
import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// Click opens the timer / alarm, right click switches the date format.

Text {
    text: Time.time
    color: Main.theme.colFg
    font: Main.pillFont

    HoverChip {}

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Time.date_format = Time.date_format === Time.regular ? Time.verbose : Time.regular;
            else
                AlarmPanel.toggle();
        }
    }
}
