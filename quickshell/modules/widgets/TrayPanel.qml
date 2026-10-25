pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.core
import qs.core.components

// Tray as a searchable list in the shared modal, like the launcher.
// Enter activates, Ctrl+L (or right click) opens the item's menu, middle click is the secondary action.
Scope {
    id: root
    readonly property alias opened: modal.opened
    property string query: ""
    property int selected: 0

    function itemName(it) {
        return it.tooltipTitle || it.title || it.id || "";
    }

    function matches(it, q) {
        return [it.title, it.tooltipTitle, it.id].some(s => s && String(s).toLowerCase().includes(q));
    }

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const all = SystemTray.items.values.filter(it => !q || matches(it, q));
        return all.sort((a, b) => itemName(a).localeCompare(itemName(b)));
    }

    function toggle() {
        if (opened) {
            modal.hide();
            return;
        }
        query = "";
        selected = 0;
        modal.show();
        search.forceActiveFocus();
    }

    function show() {
        if (!opened)
            toggle();
    }

    function hide() {
        modal.hide();
    }

    function move(d) {
        if (results.length > 0)
            selected = Math.max(0, Math.min(results.length - 1, selected + d));
    }

    function activate(i) {
        const it = results[i];
        if (!it)
            return;
        if (it.onlyMenu) {
            openMenu(i);
            return;
        }
        modal.hide();
        it.activate();
    }

    function openMenu(i) {
        const it = results[i];
        const win = search.QsWindow.window;
        if (!it?.hasMenu || !win)
            return;
        const pos = search.mapToItem(null, 0, search.height + 16);
        it.display(win, pos.x, pos.y);
    }

    onQueryChanged: selected = 0

    Modal {
        id: modal
        maxWidth: 520
        fromBottom: true
        duration: 220
        maxHeight: Math.min(420, 66 + Math.max(list.contentHeight, 46) + padding * 2)
        padding: 16
        bindings: [
            { keys: "<Down>", desc: "next", run: () => root.move(1) },
            { keys: "<Up>", desc: "previous", run: () => root.move(-1) },
            { keys: "<C-j>", desc: "next", run: () => root.move(1) },
            { keys: "<C-k>", desc: "previous", run: () => root.move(-1) },
            { keys: "<C-n>", desc: "", run: () => root.move(1) },
            { keys: "<C-p>", desc: "", run: () => root.move(-1) },
            { keys: "<Tab>", desc: "", run: () => root.move(1) },
            { keys: "<S-Tab>", desc: "", run: () => root.move(-1) },
            { keys: "<C-l>", desc: "menu", run: () => root.openMenu(root.selected) },
            { keys: "<CR>", desc: "activate", run: () => root.activate(root.selected) }
        ]

        Item {
            id: field
            width: parent.width
            height: 46

            Divider {
                anchors.bottom: parent.bottom
                width: parent.width
            }

            Text {
                id: fieldIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f003b}"
                color: Main.theme.colAccentMid
                font: Main.barFont
            }
            TextInput {
                id: search
                anchors.left: fieldIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                onTextEdited: root.query = text
                color: Main.theme.colFg
                selectionColor: Main.theme.colAccentDark
                font.family: Main.fontFamily
                font.pixelSize: 15
                clip: true
                Keys.onReturnPressed: root.activate(root.selected)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: "Search tray…"
                    color: Main.theme.colAccentDark
                    font: search.font
                }
            }
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

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.query ? "No matches" : "Nothing in the tray"
                color: Main.theme.colAccentDark
                font: Main.smallFont
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === root.selected
                width: ListView.view.width
                height: 46
                radius: Main.radius
                color: current ? Main.theme.overlay(0.07) : (rowMouse.containsMouse ? Main.theme.overlay(0.04) : "transparent")

                Rectangle {
                    visible: row.current
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 26
                    radius: 2
                    color: Main.theme.colBlue
                }

                IconImage {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 26
                    source: row.modelData.icon
                }

                Column {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 12
                    anchors.right: tag.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        width: parent.width
                        text: root.itemName(row.modelData)
                        color: Main.theme.colFg
                        font.family: Main.fontFamily
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.tooltipDescription ?? ""
                        color: Main.theme.colAccentMid
                        font: Main.smallFont
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: tag
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.onlyMenu ? "menu" : row.modelData.hasMenu ? "C-l menu" : ""
                    color: row.current ? Main.theme.colBlue : Main.theme.colAccentDark
                    font: Main.smallFont
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        root.selected = row.index;
                        if (mouse.button === Qt.MiddleButton)
                            row.modelData.secondaryActivate();
                        else if (mouse.button === Qt.RightButton)
                            root.openMenu(row.index);
                        else
                            root.activate(row.index);
                    }
                }
            }
        }
    }
}
