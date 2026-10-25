import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.services

// A workspace in miniature: wallpaper plus a live capture of each window. With `dragLayer`
// set, windows can be dragged out and `windowDropped` reports where.
Item {
    id: root
    // a workspace from Windows.workspaces
    required property var ws
    // streamed every frame; otherwise a new frame every `refreshInterval` ms (0: never)
    property bool live: false
    property int refreshInterval: 1000
    property bool wallpaper: true
    // lowercase search text: windows whose app id or title contain it are outlined
    property string query: ""
    property Item dragLayer: null

    readonly property real s: width / Math.max(1, ws.rect.width)
    readonly property bool empty: ws.windows.length === 0

    signal windowClicked(var win)
    // `pos` in window (scene) coordinates
    signal windowDragged(var win, point pos)
    signal windowDropped(var win, point pos)

    implicitHeight: ws.rect.height * s

    Image {
        anchors.fill: parent
        visible: root.wallpaper
        source: Wallpaper.url
        sourceSize.width: Math.max(320, Math.ceil(root.width / 320) * 320)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Timer {
        interval: Math.max(100, root.refreshInterval)
        running: !root.live && root.refreshInterval > 0 && root.visible
        repeat: true
        onTriggered: {
            for (let i = 0; i < tiles.count; i++)
                tiles.itemAt(i)?.capture();
        }
    }

    Repeater {
        id: tiles
        // keyed, so a refresh keeps the captures running
        model: ScriptModel {
            objectProp: "id"
            values: root.ws.windows.slice().sort((a, b) => (a.floating - b.floating) || (a.fullscreen - b.fullscreen))
        }

        Item {
            id: slot
            required property var modelData
            x: Math.round(modelData.rect.x * root.s)
            y: Math.round(modelData.rect.y * root.s)
            width: Math.round(modelData.rect.width * root.s)
            height: Math.round(modelData.rect.height * root.s)

            function capture() {
                view.captureFrame();
            }

            ClippingRectangle {
                id: tile
                width: slot.width
                height: slot.height
                radius: Math.max(1, Main.radius * root.s)
                color: Main.theme.colSurface
                border.color: Main.theme.overlay(0.08)
                border.width: 1
                opacity: dragArea.drag.active ? 0.85 : 1
                scale: dragArea.drag.active ? 1.06 : 1

                // captured at full size, scaled down by shaders/downsample.frag
                readonly property size src: view.sourceSize.width > 0 ? view.sourceSize : Qt.size(Math.max(1, slot.width), Math.max(1, slot.height))

                ScreencopyView {
                    id: view
                    width: tile.src.width
                    height: tile.src.height
                    captureSource: slot.modelData.toplevel
                    live: root.live
                }

                ShaderEffectSource {
                    id: texture
                    sourceItem: view
                    hideSource: true
                    mipmap: true
                    smooth: true
                    visible: false
                }

                ShaderEffect {
                    anchors.fill: parent
                    visible: view.hasContent
                    property var source: texture
                    property size srcSize: tile.src
                    property size dstSize: Qt.size(width, height)
                    fragmentShader: "file://" + Quickshell.shellPath("shaders/downsample.frag.qsb")
                }

                IconImage {
                    anchors.centerIn: parent
                    visible: !view.hasContent
                    implicitSize: Math.min(48, parent.height / 3)
                    source: slot.modelData.icon ? Quickshell.iconPath(slot.modelData.icon, true) : ""
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Main.radius
                    color: "transparent"
                    visible: root.query !== "" && (slot.modelData.appId + " " + slot.modelData.title).toLowerCase().includes(root.query)
                    border.color: Main.theme.colBlue
                    border.width: 2
                }

                states: State {
                    when: dragArea.drag.active
                    ParentChange {
                        target: tile
                        parent: root.dragLayer
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                enabled: root.dragLayer !== null
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                drag.target: tile
                drag.threshold: 6
                property bool dragged: false
                readonly property bool dragging: drag.active

                function scenePos(mouse) {
                    return mapToItem(null, mouse.x, mouse.y);
                }

                onPressed: dragged = false
                onDraggingChanged: if (dragging) dragged = true
                onPositionChanged: mouse => {
                    if (drag.active)
                        root.windowDragged(slot.modelData, scenePos(mouse));
                }
                onReleased: mouse => {
                    if (dragged)
                        root.windowDropped(slot.modelData, scenePos(mouse));
                    else
                        root.windowClicked(slot.modelData);
                    tile.x = 0;
                    tile.y = 0;
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.empty
        text: "empty"
        color: Main.theme.colMuted
        font: Main.barFont
    }
}
