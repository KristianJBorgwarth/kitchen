import QtQuick
import qs.core
import qs.services
import qs.modules.widgets

// Time left in the running or paused pomodoro phase.
// Click opens the panel, middle click starts/pauses, right click skips.
Text {
    id: root
    anchors.verticalCenter: parent.verticalCenter

    text: (Pomodoro.barPhase === "focus" ? "󰔛 " : "󰾩 ") + Pomodoro.fmt(Pomodoro.remaining(Pomodoro.barPhase))
    opacity: Pomodoro.isRunning(Pomodoro.barPhase) ? 1 : 0.55
    color: Pomodoro.barPhase === "focus" ? Main.theme.colRed : Pomodoro.barPhase === "short" ? Main.theme.colGreen : Main.theme.colBlue
    font: Main.pillFont

    HoverChip {}

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                Pomodoro.toggle(Pomodoro.barPhase);
            else if (mouse.button === Qt.RightButton)
                Pomodoro.skip(Pomodoro.barPhase);
            else
                PomodoroPanel.toggle();
        }
    }
}
