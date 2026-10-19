import QtQuick
import Quickshell.Wayland

// A monitor frozen at the moment it's created, with any children (the drawings) laid over it
// in the monitor's coordinates. Fills its parent; a non-empty `crop` shrinks it to that
// rectangle, so grab() then captures exactly the cropped frame with what's on it.
Item {
    id: root
    required property var screen
    property rect crop: Qt.rect(0, 0, 0, 0)
    readonly property bool cropping: crop.width > 0 && crop.height > 0
    readonly property bool ready: view.hasContent
    readonly property alias view: view
    default property alias content: monitor.data

    function grab(callback): void {
        const dpr = screen.devicePixelRatio ?? 1;
        grabToImage(callback, Qt.size(Math.round(width * dpr), Math.round(height * dpr)));
    }

    x: cropping ? crop.x : 0
    y: cropping ? crop.y : 0
    width: cropping ? crop.width : parent.width
    height: cropping ? crop.height : parent.height
    clip: true

    // the whole monitor, shifted so the frame stays put while the clip shrinks around it
    Item {
        id: monitor
        x: -root.x
        y: -root.y
        width: root.screen.width
        height: root.screen.height

        ScreencopyView {
            id: view
            anchors.fill: parent
            captureSource: root.screen
            live: false
        }
    }
}
