import QtQuick
import Quickshell.Widgets
import qs.core

Item {
    id: root
    property bool opened: false
    property real maxWidth: 1000
    property real maxHeight: 700
    property real padding: 24
    property real radius: Main.radius
    property bool frameless: false  // no card fill or border; content floats on the backdrop
    property real dim: 0  // backdrop opacity while this modal is open
    property bool fromBottom: false  // dock to the bottom edge and slide up instead of centering
    property real edgeMargin: 24  // gap to the bottom edge when fromBottom
    property bool rise: false  // centered, but slides up into place like fromBottom
    property int duration: Main.anim  // open/close animation length in ms
    property var bindings: []
    property bool framed: false
    property alias actions: actionRow.data
    property alias headerLeft: leftRow.data  // header items aligned left instead of beside the buttons
    property alias headerCenter: centerRow.data  // header items centered in the card

    default property alias content: body.data
    property alias background: backgroundSlot.data
    readonly property alias body: body
    readonly property alias card: card
    readonly property alias vimKeys: keys

    signal closed
    signal keyReleased(var event)

    function show() {
        ModalHost.open(root);
        opened = true;
        body.forceActiveFocus();
    }

    function hide() {
        if (!opened)
            return;
        opened = false;
        ModalHost.release(root);
        closed();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    parent: ModalHost.stage
    anchors.fill: parent ?? undefined
    visible: card.opacity > 0

    Rectangle {
        id: card
        // whole pixels, so text inside lands on the pixel grid
        x: Math.round((root.width - width) / 2)
        y: root.fromBottom ? root.height - height - root.edgeMargin : Math.round((root.height - height) / 2)
        width: Math.round(Math.min(root.maxWidth, root.width - 64))
        height: Math.round(Math.min(root.maxHeight, root.height - 64))
        radius: root.radius
        color: root.frameless ? "transparent" : Main.theme.colBg
        border.color: Main.theme.overlay(0.08)
        border.width: root.frameless ? 0 : 1

        readonly property bool slides: root.fromBottom || root.rise
        // sliding cards only fade and move: scaling text mid-motion makes it shimmer
        scale: slides || root.opened ? 1 : 0.96
        opacity: root.opened ? 1 : 0

        // the slide is its own offset, so the card resizing while it opens doesn't disturb it
        transform: Translate {
            y: card.slides && !root.opened ? 40 : 0
            Behavior on y {
                NumberAnimation {
                    duration: root.duration
                    easing.type: Easing.OutQuint
                }
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.duration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.duration
                easing.type: Easing.OutCubic
            }
        }

        // swallow clicks so they don't reach the backdrop
        MouseArea {
            anchors.fill: parent
        }

        // only the background goes through the rounded clip: it renders to a texture, which
        // would soften any text drawn inside it
        ClippingRectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            Item {
                id: backgroundSlot
                anchors.fill: parent
            }
        }

        // with no actions the row takes no space: the close button floats over the content's corner
        Item {
            id: header
            readonly property bool hasActions: actionRow.children.length + leftRow.children.length + centerRow.children.length > 0
            visible: root.framed
            z: 1
            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            height: 28

            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
            }
            Row {
                id: centerRow
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
            }
            Row {
                id: actionRow
                anchors.right: closeButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
            }
            Text {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅖"
                color: closeMouse.containsMouse ? Main.theme.colFg : Main.theme.colAccentDark
                font: Main.iconFont
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.hide()
                }
            }
        }

        Text {
            id: footer
            visible: root.framed
            x: root.padding
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.padding - 4
            text: "q close   ? keys"
            color: Main.theme.colAccentDark
            font: Main.smallFont
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: root.padding
            anchors.topMargin: root.framed && header.hasActions ? root.padding + header.height + Main.gap : root.padding
            anchors.bottomMargin: root.framed ? root.padding + footer.implicitHeight + 8 : root.padding
            focus: true
            Keys.onPressed: event => keys.handle(event)
            Keys.onReleased: event => root.keyReleased(event)
        }

        KeyHelp {
            vimKeys: keys
        }
    }

    VimKeys {
        id: keys
        readonly property var defaults: [
            { keys: "q", desc: "close", run: () => root.hide() },
            { keys: "<Esc>", desc: "", run: () => root.hide() }
        ]
        bindings: root.bindings.concat(defaults.filter(d => !root.bindings.some(b => b.keys === d.keys)))
    }
}
