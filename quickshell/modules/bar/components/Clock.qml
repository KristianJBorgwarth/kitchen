// ClockWidget.qml
import QtQuick
import qs.core
import qs.services

// Click switches the date format.

Text {
    text: Time.time
    color: Main.theme.colFg
    font: Main.pillFont

    HoverChip {}

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Time.date_format = Time.date_format === Time.regular ? Time.verbose : Time.regular
    }
}
