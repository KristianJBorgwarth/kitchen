import QtQuick
import Quickshell.Widgets
import qs.core

// Modal — a centered card in the shared ModalHost overlay: size, open/close animation,
// vim keys (q and <Esc> close unless `bindings` defines them) and the ? cheat sheet.
// Children go in the padded body; `background` fills the whole card underneath it.
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
    property int duration: Main.anim  // open/close animation length in ms
    property var bindings: []
    // set a title for the shared frame: header (glyph, title, `actions`, close) and key hints
    property string title: ""
    property string glyph: ""
    property alias actions: actionRow.data
    readonly property bool framed: title !== ""

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
        y: root.fromBottom ? root.height - height - root.edgeMargin + (root.opened ? 0 : 48) : Math.round((root.height - height) / 2)
        width: Math.round(Math.min(root.maxWidth, root.width - 64))
        height: Math.round(Math.min(root.maxHeight, root.height - 64))
        radius: root.radius
        color: root.frameless ? "transparent" : Main.theme.colBg
        border.color: Main.theme.overlay(0.08)
        border.width: root.frameless ? 0 : 1

        scale: root.opened ? 1 : 0.96
        opacity: root.opened ? 1 : 0

        Behavior on y {
            enabled: root.fromBottom
            NumberAnimation {
                duration: root.duration
                easing.type: Easing.OutCubic
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

        Item {
            id: header
            visible: root.framed
            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            height: 28

            Text {
                id: headerGlyph
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph !== ""
                text: root.glyph
                color: Main.theme.colAccentMid
                font: Main.iconFont
            }
            Text {
                anchors.left: headerGlyph.visible ? headerGlyph.right : parent.left
                anchors.leftMargin: headerGlyph.visible ? 10 : 0
                anchors.right: actionRow.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: Main.theme.colFg
                font: Main.titleFont
                elide: Text.ElideRight
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
            anchors.topMargin: root.framed ? root.padding + header.height + Main.gap : root.padding
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
