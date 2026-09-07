pragma Singleton

import QtQuick
import Quickshell
import qs.core
import qs.services

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    anchors.top: true
    anchors.right: true

    implicitWidth: 320
    implicitHeight: 110

    margins {
        top: 4
        left: 4
        bottom: 4
        right: 4
    }

    property bool opened: false

    function show() {
        unmapTimer.stop();
        root.visible = true;
        opened = true;
    }

    function hide() {
        opened = false;
        unmapTimer.restart();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    Timer {
        id: unmapTimer
        interval: 220
        onTriggered: {
            if (!root.opened)
                root.visible = false;
        }
    }
}
