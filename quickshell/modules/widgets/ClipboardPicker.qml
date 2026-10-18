pragma Singleton

import QtQuick
import Quickshell
import qs.core
import qs.core.components
import qs.services

// Clipboard history picker: Enter pastes the entry into the window you were in.
Scope {
    id: root
    readonly property alias opened: modal.opened
    property string query: ""
    property int selected: 0

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q ? Clipboard.entries.filter(e => e.text.toLowerCase().includes(q)) : Clipboard.entries;
    }

    onQueryChanged: selected = 0

    function toggle() {
        if (opened) {
            modal.hide();
            return;
        }
        query = "";
        selected = 0;
        Clipboard.refresh();
        modal.show();
        search.forceActiveFocus();
    }

    function move(d) {
        if (results.length > 0)
            selected = Math.max(0, Math.min(results.length - 1, selected + d));
    }

    function pick(copyOnly) {
        const e = results[selected];
        if (!e)
            return;
        modal.hide();
        if (copyOnly || !Clipboard.canPaste)
            Clipboard.copy(e);
        else
            Clipboard.paste(e, Focus.isTerminal);
    }

    Modal {
        id: modal
        maxWidth: 700
        maxHeight: Math.min(480, 66 + list.contentHeight + padding * 2)
        padding: 16
        bindings: [
            { keys: "<Down>", desc: "next", run: () => root.move(1) },
            { keys: "<Up>", desc: "previous", run: () => root.move(-1) },
            { keys: "<C-j>", desc: "next", run: () => root.move(1) },
            { keys: "<C-k>", desc: "previous", run: () => root.move(-1) },
            { keys: "<Tab>", desc: "", run: () => root.move(1) },
            { keys: "<S-Tab>", desc: "", run: () => root.move(-1) },
            { keys: "<CR>", desc: "paste", run: () => root.pick(false) },
            { keys: "<C-d>", desc: "delete entry", run: () => { const e = root.results[root.selected]; if (e) Clipboard.remove(e); } }
        ]

        Rectangle {
            id: field
            width: parent.width
            height: 46
            radius: Main.radius
            color: Main.theme.colSurface
            border.color: Main.theme.colMuted
            border.width: 1

            Text {
                id: fieldIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅌"
                color: Main.theme.colAccentMid
                font: Main.barFont
            }
            TextInput {
                id: search
                anchors.left: fieldIcon.right
                anchors.leftMargin: 10
                anchors.right: hint.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                onTextEdited: root.query = text
                color: Main.theme.colFg
                selectionColor: Main.theme.colAccentDark
                font.family: Main.fontFamily
                font.pixelSize: 15
                clip: true
                // shift+enter only copies
                Keys.onReturnPressed: event => root.pick(event.modifiers & Qt.ShiftModifier)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: "Search clipboard history…"
                    color: Main.theme.colAccentDark
                    font: search.font
                }
            }
            Text {
                id: hint
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Clipboard.canPaste ? "↵ paste   ⇧↵ copy   ^d delete" : "↵ copy  ·  install wtype to paste"
                color: Main.theme.colAccentDark
                font: Main.smallFont
            }
        }

        Text {
            anchors.top: field.bottom
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.results.length === 0
            text: Clipboard.entries.length === 0 ? "Clipboard history is empty" : "Nothing matches"
            color: Main.theme.colAccentDark
            font: Main.barFont
        }

        ListView {
            id: list
            anchors.top: field.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.selected
            highlightMoveDuration: 0
            model: ScriptModel {
                values: root.opened ? root.results : []
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === root.selected
                width: ListView.view.width
                height: 46
                radius: Main.radius
                color: current ? Qt.rgba(Main.theme.colBlue.r, Main.theme.colBlue.g, Main.theme.colBlue.b, 0.16) : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                Rectangle {
                    visible: row.current
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 22
                    radius: 2
                    color: Main.theme.colBlue
                }

                Text {
                    id: glyph
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.image ? "󰋩" : "󰅍"
                    color: row.current ? Main.theme.colBlue : Main.theme.colAccentMid
                    font: Main.barFont
                }

                Text {
                    anchors.left: glyph.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text
                    color: row.modelData.image ? Main.theme.colAccentLight : Main.theme.colFg
                    font.family: Main.fontFamily
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selected = row.index;
                        root.pick(false);
                    }
                }
            }
        }
    }
}
