pragma Singleton

import QtQuick
import Quickshell
import qs.core.themes

Singleton {
    id: root
    property Theme theme: Theme {}
    property string fontFamily: "JetBrainsMono Nerd Font Propo"
    readonly property int anim: 50
    readonly property int radius: 8

    property font barFont: Qt.font({
        family: root.fontFamily,
        pixelSize: 13
    })

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
