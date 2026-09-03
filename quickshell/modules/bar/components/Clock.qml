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

  MouseArea {
    anchors.fill: parent
    onClicked: {
      Time.date_format = Time.date_format === Time.regular ? Time.long : Time.regular
    }
  }
}
