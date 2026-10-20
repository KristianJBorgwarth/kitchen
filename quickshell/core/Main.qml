pragma Singleton

import QtQuick
import Quickshell
import qs.core.themes

Singleton {
    id: root
    property Theme theme: Theme {}
    property string fontFamily: "JetBrainsMono Nerd Font Propo"
    // how long UI motion takes (open/close, dim, hovers); data smoothing has its own timings
    readonly property int anim: 50
    // corner radius for everything boxy: cards, islands, chips, buttons, popups
    readonly property int radius: 4

    property font barFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 13
    })

    // the bar's own text, a size up from barFont (which most popups use)
    property font pillFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 14
    })

    property font iconFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 18
    })

    property font smallFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 11
    })
}
