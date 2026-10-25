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
    // corner radius for everything boxy: cards, islands, chips, buttons, popups. Hyprland
    // rounds windows the same (decoration.rounding in hypr/conf/appearance.lua)
    readonly property int radius: 8

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

    // panel type scale: smallFont, barFont, then these
    property font titleFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 15,
        weight: Font.DemiBold
    })
    property font displayFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 26,
        weight: Font.Light
    })
    property font heroFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 48,
        weight: Font.Light
    })

    // panel spacing
    readonly property int pad: 20
    readonly property int gap: 12
}
