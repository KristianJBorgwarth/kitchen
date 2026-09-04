pragma Singleton

import QtQuick
import Quickshell
import qs.core.themes

Singleton {
    id: root
    property Monochrome theme: Monochrome{}
    property string fontFamily: "JetBrainsMono Nerd Font Propo"

    property font barFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 13
    })
}
