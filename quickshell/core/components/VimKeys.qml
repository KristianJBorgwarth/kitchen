import QtQuick

// bindings: [{ keys: "gg" | "h" | "<C-d>" | "<Esc>", desc, run }]. Multi-key sequences wait
// `timeout` ms for the next key, like vim's timeoutlen; "?" toggles helpVisible for KeyHelp.
Item {
    id: root
    property var bindings: []
    property int timeout: 800
    property bool helpVisible: false
    property string pending: ""

    visible: false

    Timer {
        id: pendingTimer
        interval: root.timeout
        onTriggered: {
            const exact = root.bindings.find(b => b.keys === root.pending);
            root.pending = "";
            if (exact)
                exact.run();
        }
    }

    function keyName(event) {
        const special = {
            [Qt.Key_Escape]: "Esc",
            [Qt.Key_Return]: "CR",
            [Qt.Key_Enter]: "CR",
            [Qt.Key_Space]: "Space",
            [Qt.Key_Tab]: "Tab",
            [Qt.Key_Backtab]: "S-Tab",
            [Qt.Key_Backspace]: "BS",
            [Qt.Key_Left]: "Left",
            [Qt.Key_Right]: "Right",
            [Qt.Key_Up]: "Up",
            [Qt.Key_Down]: "Down"
        };
        if (special[event.key])
            return "<" + special[event.key] + ">";
        if (event.modifiers & Qt.ControlModifier && event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return "<C-" + String.fromCharCode(event.key).toLowerCase() + ">";
        return event.text;
    }

    function handle(event) {
        const name = keyName(event);
        if (!name)
            return;
        event.accepted = true;

        if (name === "?") {
            helpVisible = !helpVisible;
            pending = "";
            return;
        }
        if (helpVisible && name === "<Esc>") {
            helpVisible = false;
            return;
        }

        for (const seq of [pending + name, name]) {
            const exact = bindings.find(b => b.keys === seq);
            const longer = bindings.some(b => b.keys.length > seq.length && b.keys.startsWith(seq));
            if (longer) {
                // ambiguous ("g" vs "gg"): wait for the next key, run the short one on timeout
                pending = seq;
                pendingTimer.restart();
                return;
            }
            if (exact) {
                pending = "";
                pendingTimer.stop();
                exact.run();
                return;
            }
            if (!pending)
                break;
        }
        pending = "";
        event.accepted = false;
    }
}
