pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

// Wallpaper picker: a carousel of the wallpapers, the selected one large in the middle,
// laid out like the workspace switcher. Enter applies the selection.
Scope {
    id: root
    readonly property alias opened: modal.opened
    property string query: ""
    // tracked by path so filtering doesn't move the selection
    property string selectedPath: ""
    // false right after opening: the carousel jumps to the selection instead of sliding
    property bool settled: false

    readonly property string q: query.trim().toLowerCase()
    readonly property var items: Wallpaper.files.filter(f => q === "" || name(f).toLowerCase().includes(q))
    readonly property int selectedIndex: Math.max(0, items.indexOf(selectedPath))
    readonly property string selected: items[selectedIndex] ?? ""

    function name(p) {
        return p.split("/").pop().replace(/\.[^.]+$/, "");
    }

    onItemsChanged: {
        if (!items.includes(selectedPath))
            selectedPath = items[0] ?? "";
    }

    function toggle() {
        if (opened) {
            modal.hide();
            return;
        }
        query = "";
        selectedPath = Wallpaper.path;
        settled = false;
        settleOpen.restart();
        modal.show();
        Qt.callLater(carousel.sync);
    }

    function step(d) {
        if (items.length > 0)
            selectedPath = items[Math.max(0, Math.min(items.length - 1, selectedIndex + d))];
    }

    function commit() {
        if (selected)
            Wallpaper.set(selected);
        modal.hide();
    }

    Timer {
        id: settleOpen
        interval: 200
        onTriggered: root.settled = true
    }

    Modal {
        id: modal
        maxWidth: Infinity  // screen width minus the 32px edge gutter
        maxHeight: 760
        padding: 24
        frameless: true
        dim: 0.8
        bindings: [
            { keys: "l", desc: "next", run: () => root.step(1) },
            { keys: "h", desc: "previous", run: () => root.step(-1) },
            { keys: "<Right>", desc: "", run: () => root.step(1) },
            { keys: "<Left>", desc: "", run: () => root.step(-1) },
            { keys: "<Tab>", desc: "", run: () => root.step(1) },
            { keys: "<S-Tab>", desc: "", run: () => root.step(-1) },
            { keys: "gg", desc: "first", run: () => root.step(-1e3) },
            { keys: "G", desc: "last", run: () => root.step(1e3) },
            { keys: "r", desc: "random", run: () => { Wallpaper.random(); modal.hide(); } },
            { keys: "<CR>", desc: "apply", run: () => root.commit() },
            { keys: "/", desc: "search", run: () => search.forceActiveFocus() },
            { keys: "<Esc>", desc: "", run: () => root.query ? root.query = "" : modal.hide() }
        ]

        Item {
            id: header
            width: parent.width
            height: 36

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 280
                    height: 32
                    radius: Main.radius
                    color: Main.theme.colSurface
                    border.color: search.activeFocus ? Main.theme.colBlue : Main.theme.colMuted
                    border.width: 1

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        color: Main.theme.colAccentMid
                        font: Main.barFont
                    }
                    TextInput {
                        id: search
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query
                        onTextEdited: root.query = text
                        color: Main.theme.colFg
                        selectionColor: Main.theme.colAccentDark
                        font: Main.barFont
                        clip: true

                        Keys.onReturnPressed: root.commit()
                        Keys.onEscapePressed: modal.body.forceActiveFocus()
                        Keys.onTabPressed: root.step(1)
                        Keys.onBacktabPressed: root.step(-1)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text && !search.activeFocus
                            text: "/ to search"
                            color: Main.theme.colAccentDark
                            font: Main.barFont
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "? keys"
                    color: Main.theme.colAccentDark
                    font: Main.smallFont
                }
            }
        }

        ListView {
            id: carousel
            anchors.top: header.bottom
            anchors.topMargin: 16
            anchors.bottom: info.top
            anchors.bottomMargin: 16
            width: parent.width
            orientation: ListView.Horizontal
            interactive: false
            clip: true
            spacing: 28

            readonly property real slotW: width * 0.58
            model: ScriptModel {
                values: root.opened ? root.items : []
            }
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - slotW) / 2
            preferredHighlightEnd: (width + slotW) / 2
            highlightMoveDuration: root.settled ? 180 : 0
            highlightMoveVelocity: -1

            // set explicitly rather than bound: replacing rows resets the view's own index
            function sync() {
                if (count === 0)
                    return;
                currentIndex = root.selectedIndex;
                if (!root.settled)
                    positionViewAtIndex(root.selectedIndex, ListView.Center);
            }
            onCountChanged: sync()
            Connections {
                target: root
                function onSelectedIndexChanged() {
                    carousel.sync();
                }
                function onItemsChanged() {
                    carousel.sync();
                }
            }

            delegate: Item {
                id: slot
                required property string modelData
                required property int index
                readonly property bool current: index === root.selectedIndex
                // distance from the middle in slots, for the depth effect
                readonly property real d: (x + width / 2 - carousel.contentX - carousel.width / 2) / carousel.slotW
                readonly property real ad: Math.min(2, Math.abs(d))

                width: carousel.slotW
                height: carousel.height
                z: 10 - ad
                scale: 1 - 0.24 * ad
                opacity: 1 - 0.4 * ad

                transform: Translate {
                    x: -slot.d * carousel.slotW * 0.12
                }

                RectangularShadow {
                    anchors.fill: frame
                    radius: frame.radius
                    blur: 30
                    offset.y: 8
                    color: Qt.rgba(0, 0, 0, 0.6)
                }

                Rectangle {
                    id: frame
                    anchors.centerIn: parent
                    height: Math.min(parent.height, parent.width / (16 / 9))
                    width: height * 16 / 9
                    radius: Main.radius
                    color: Main.theme.colSurface
                    border.color: slot.current ? Main.theme.colBlue : Main.theme.overlay(0.14)
                    border.width: slot.current ? 2 : 1

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: Main.radius
                        color: Main.theme.colBg

                        Image {
                            anchors.fill: parent
                            source: "file://" + slot.modelData
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(1280, 720)
                        }

                        Rectangle {
                            visible: slot.modelData === Wallpaper.path
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            width: currentLabel.implicitWidth + 16
                            height: 24
                            radius: Main.radius
                            color: Qt.rgba(0, 0, 0, 0.6)
                            Text {
                                id: currentLabel
                                anchors.centerIn: parent
                                text: "current"
                                color: Main.theme.colFg
                                font: Main.smallFont
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: slot.current ? root.commit() : root.selectedPath = slot.modelData
                    }
                }
            }
        }

        Item {
            id: info
            anchors.bottom: parent.bottom
            width: parent.width
            height: 40

            Row {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.name(root.selected)
                    color: Main.theme.colFg
                    font.family: Main.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.items.length > 0
                    text: (root.selectedIndex + 1) + " / " + root.items.length
                    color: Main.theme.colAccentMid
                    font: Main.smallFont
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.items.length === 0
                text: "no wallpapers found"
                color: Main.theme.colMuted
                font: Main.barFont
            }
        }
    }
}
