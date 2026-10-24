import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.core

// A saved screenshot sliding in at the bottom-right of the focused monitor for a few
// seconds (held while hovered): click opens it, drag it into an app, right-click dismisses.
PanelWindow {
    id: root
    property string path: ""
    property bool shown: false

    function show(p: string): void {
        path = p;
        shown = true;
        hideTimer.restart();
    }

    function hide(): void {
        shown = false;
    }

    Timer {
        id: hideTimer
        interval: 5000
        onTriggered: root.hide()
    }

    screen: Quickshell.screens.find(s => s.name === Compositor.focusedMonitor) ?? null
    visible: card.opacity > 0
    color: "transparent"
    anchors.bottom: true
    anchors.right: true
    margins.bottom: 12
    margins.right: 12
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot-preview"
    implicitWidth: 320
    implicitHeight: card.implicitHeight

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: thumb.height + 54
        x: root.shown ? 0 : 40
        opacity: root.shown ? 1 : 0
        radius: Main.radius
        color: Main.theme.colBg
        border.color: Main.theme.colMuted
        border.width: 1

        Behavior on x {
            NumberAnimation {
                duration: Main.anim
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Main.anim
            }
        }

        Image {
            id: thumb
            x: 8
            y: 8
            width: parent.width - 16
            height: Math.min(180, implicitHeight > 0 ? width * implicitHeight / Math.max(1, implicitWidth) : 120)
            source: root.path ? "file://" + root.path : ""
            sourceSize.width: 600
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: true
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            text: "<b>Copied</b>  ·  " + root.path.split("/").pop()
            textFormat: Text.StyledText
            color: Main.theme.colFg
            font: Main.smallFont
            elide: Text.ElideMiddle
        }

        Item {
            id: dragProxy
            Drag.active: dragArea.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": "file://" + root.path })
            Drag.imageSource: thumb.source
            Drag.imageSourceSize: Qt.size(160, Math.round(160 * thumb.implicitHeight / Math.max(1, thumb.implicitWidth)))
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            drag.target: dragProxy
            onContainsMouseChanged: {
                if (containsMouse)
                    hideTimer.stop();
                else if (root.shown)
                    hideTimer.restart();
            }
            onClicked: m => {
                if (m.button === Qt.LeftButton)
                    Quickshell.execDetached(["xdg-open", root.path]);
                root.hide();
            }
            onReleased: dragProxy.x = dragProxy.y = 0
        }
    }
}
