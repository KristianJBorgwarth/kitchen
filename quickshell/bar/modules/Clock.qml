// ClockWidget.qml
import QtQuick
import qs.core

Text {
  text: Time.time
  color: Main.theme.colFg
  font {
    family: "Jetbrains Mono Nerd Font"
    pixelSize: 14
  }
}
