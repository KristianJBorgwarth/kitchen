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
    property real radius: 16
    property var bindings: []

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

    // ClippingRectangle (not clip: true) keeps backgrounds inside the rounded corners
    ClippingRectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.maxWidth, root.width - 64)
        height: Math.min(root.maxHeight, root.height - 64)
        radius: root.radius
        color: Main.theme.colBg
        border.color: Main.theme.colMuted
        border.width: 1

        scale: root.opened ? 1 : 0.96
        opacity: root.opened ? 1 : 0

        Behavior on scale {
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

        // swallow clicks so they don't reach the backdrop
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: backgroundSlot
            anchors.fill: parent
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: root.padding
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
