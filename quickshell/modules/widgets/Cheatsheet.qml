pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.core.components
import qs.services
import "components"

// Sway keybind cheatsheet: centered card of sections parsed live from the sway config.
// Vim keys: j/k scroll, ctrl-d/u half page, gg/G top/bottom, / search, q or esc close.
Scope {
    id: root
    property bool opened: false
    property string query: ""

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        if (!q)
            return Keybinds.sections;
        return Keybinds.sections.map(s => {
            const inTitle = s.title.toLowerCase().includes(q);
            const rows = s.rows.filter(r => inTitle || (r.desc + " " + r.detail + " " + r.combos.map(c => c.join(" ")).join(" ")).toLowerCase().includes(q));
            return { title: s.title, rows };
        }).filter(s => s.rows.length > 0);
    }

    function show() {
        Keybinds.reload();
        query = "";
        unmapTimer.stop();
        const focused = Quickshell.screens.find(s => s.name === I3.focusedMonitor?.name);
        if (focused)
            win.screen = focused;
        win.visible = true;
        opened = true;
        flick.contentY = 0;
        body.forceActiveFocus();
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
        interval: 250
        onTriggered: {
            if (!root.opened)
                win.visible = false;
        }
    }

    PanelWindow {
        id: win
        visible: false
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-keybinds"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // dim + click-outside-to-close
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.opened ? 0.5 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        ClippingRectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(760, parent.width - 80)
            height: Math.min(900, parent.height - 80)
            radius: 14
            color: Main.theme.colBg
            border.color: Main.theme.colMuted
            border.width: 1

            scale: root.opened ? 1 : 0.94
            opacity: root.opened ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            // swallow clicks so they don't reach the backdrop
            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: body
                anchors.fill: parent
                anchors.margins: 22
                focus: true

                Keys.onPressed: event => vimKeys.handle(event)

                VimKeys {
                    id: vimKeys
                    bindings: [
                        { keys: "j", desc: "scroll down", run: () => root.scrollBy(80) },
                        { keys: "k", desc: "scroll up", run: () => root.scrollBy(-80) },
                        { keys: "<Down>", desc: "", run: () => root.scrollBy(80) },
                        { keys: "<Up>", desc: "", run: () => root.scrollBy(-80) },
                        { keys: "<C-d>", desc: "half page down", run: () => root.scrollBy(flick.height / 2) },
                        { keys: "<C-u>", desc: "half page up", run: () => root.scrollBy(-flick.height / 2) },
                        { keys: "gg", desc: "top", run: () => root.scrollBy(-1e9) },
                        { keys: "G", desc: "bottom", run: () => root.scrollBy(1e9) },
                        { keys: "/", desc: "search", run: () => search.forceActiveFocus() },
                        { keys: "q", desc: "close", run: () => root.hide() },
                        // esc clears a search before it closes
                        { keys: "<Esc>", desc: "", run: () => root.query ? root.query = "" : root.hide() }
                    ]
                }

                // ── header ────────────────────────────────────────────
                Item {
                    id: header
                    width: parent.width
                    height: 44

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "Keybinds"
                            color: Main.theme.colFg
                            font.family: Main.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "sway  ·  " + Keybinds.sections.reduce((n, s) => n + s.rows.length, 0) + " bindings"
                            color: Main.theme.colAccentMid
                            font: Main.smallFont
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // search
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 280
                            height: 32
                            radius: 16
                            color: Main.theme.colSurface
                            border.color: search.activeFocus ? Main.theme.colAccentMid : Main.theme.colMuted
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

                                // back to vim keys; the filter stays applied
                                Keys.onEscapePressed: body.forceActiveFocus()
                                Keys.onReturnPressed: body.forceActiveFocus()
                                Keys.onDownPressed: body.forceActiveFocus()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !search.text && !search.activeFocus
                                    text: "press / to search"
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

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰅖"
                            onClicked: root.hide()
                        }
                    }
                }

                // ── sections, stacked as a list ──────────────────────
                Flickable {
                    id: flick
                    anchors.top: header.bottom
                    anchors.topMargin: 18
                    anchors.bottom: parent.bottom
                    width: parent.width
                    contentHeight: stack.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    NumberAnimation {
                        id: scrollAnim
                        target: flick
                        property: "contentY"
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                    Column {
                        id: stack
                        width: flick.width
                        spacing: 12

                        Repeater {
                            model: root.filtered

                            Island {
                                id: island
                                required property var modelData
                                width: parent.width
                                height: rows.implicitHeight + 56
                                title: modelData.title

                                Column {
                                    id: rows
                                    width: parent.width

                                    Repeater {
                                        model: island.modelData.rows

                                        Item {
                                            id: row
                                            required property var modelData
                                            width: rows.width
                                            height: 30

                                            // app icon when the binding launches something we know, else a glyph
                                            Item {
                                                id: icon
                                                width: 22
                                                height: parent.height
                                                IconImage {
                                                    anchors.centerIn: parent
                                                    visible: row.modelData.app !== ""
                                                    implicitSize: 18
                                                    source: row.modelData.app ? Quickshell.iconPath(row.modelData.app, true) : ""
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: row.modelData.app === ""
                                                    text: row.modelData.glyph
                                                    color: Main.theme.colAccentMid
                                                    font: Main.barFont
                                                }
                                            }

                                            Text {
                                                anchors.left: icon.right
                                                anchors.leftMargin: 10
                                                anchors.right: keycaps.left
                                                anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                textFormat: Text.StyledText
                                                text: row.modelData.desc + (row.modelData.detail ? "<font color='" + Main.theme.colAccentDark + "'>  " + row.modelData.detail + "</font>" : "")
                                                color: Main.theme.colFg
                                                font: Main.barFont
                                                elide: Text.ElideRight
                                            }

                                            // keycaps; alternatives share their modifiers (Super Shift H / ←)
                                            Row {
                                                id: keycaps
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3

                                                Repeater {
                                                    model: row.modelData.parts

                                                    Item {
                                                        id: part
                                                        required property var modelData
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: part.modelData.sep ? sepText.implicitWidth + 6 : cap.width
                                                        height: 20

                                                        Text {
                                                            id: sepText
                                                            anchors.centerIn: parent
                                                            visible: !!part.modelData.sep
                                                            text: part.modelData.sep ?? ""
                                                            color: Main.theme.colAccentDark
                                                            font: Main.smallFont
                                                        }
                                                        Rectangle {
                                                            id: cap
                                                            visible: !part.modelData.sep
                                                            height: 20
                                                            width: Math.max(20, capText.implicitWidth + 12)
                                                            radius: 4
                                                            color: Main.theme.colBg
                                                            border.color: Main.theme.colMuted
                                                            border.width: 1
                                                            Text {
                                                                id: capText
                                                                anchors.centerIn: parent
                                                                text: part.modelData.cap ?? ""
                                                                color: Main.theme.colAccentLight
                                                                font: Main.smallFont
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: flick
                    visible: root.filtered.length === 0
                    text: root.query ? "No keybinds match \"" + root.query + "\"" : "No keybinds found in the sway config"
                    color: Main.theme.colAccentDark
                    font: Main.barFont
                }
            }

            KeyHelp {
                vimKeys: vimKeys
            }
        }
    }

    function scrollBy(d) {
        const max = Math.max(0, flick.contentHeight - flick.height);
        scrollAnim.stop();
        scrollAnim.to = Math.max(0, Math.min(max, flick.contentY + d));
        scrollAnim.start();
    }
}
