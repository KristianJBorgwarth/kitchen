import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.core.components

// One monitor's screenshot overlay: the frozen frame, the spotlight on the selection or the
// window under the mouse, the loupe, and the mouse and keys for selecting and drawing.
// `shot` is the Screenshot singleton, which holds the selection and the drawings.
PanelWindow {
    id: win
    required property var modelData
    required property var shot
    readonly property string name: modelData.name
    readonly property bool focusedScreen: name === (Compositor.focusedMonitor ?? "")
    readonly property bool mine: shot.selScreen === name
    readonly property var wins: shot.windowsOn(name)
    property var hover: null
    property real mx: -1
    property real my: -1
    readonly property bool mouseHere: shot.mouseScreen === name && mx >= 0

    // the lit rectangle: the selection, else the window under the mouse; empty collapses
    // to the cursor so it grows out of and shrinks into it
    readonly property rect target: mine && shot.hasSel ? shot.sel : !shot.hasSel && !shot.dragging && hover && mouseHere ? hover : Qt.rect(Math.max(0, mx), Math.max(0, my), 0, 0)

    function selectScreen(): void {
        const s = Quickshell.screens.find(s => s.name === shot.mouseScreen) ?? modelData;
        shot.select(s.name, Qt.rect(0, 0, s.width, s.height));
    }

    screen: modelData
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot"
    WlrLayershell.keyboardFocus: focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: win.shot
        function onCapturingChanged() {
            if (win.shot.capturing && win.mine)
                Qt.callLater(() => frame.grab(r => win.shot.store(r)));
        }
    }

    // nothing is drawn until the frame lands, so the capture never contains this overlay
    Item {
        id: stage
        anchors.fill: parent
        opacity: frame.ready ? 1 : 0
        focus: true
        Keys.onPressed: event => keys.handle(event)

        onOpacityChanged: {
            if (opacity === 1 && win.focusedScreen) {
                stage.forceActiveFocus();
                if (win.shot.instant === "screen") {
                    win.shot.select(win.name, Qt.rect(0, 0, win.width, win.height));
                    win.shot.finish();
                }
            }
        }

        ScreenshotFrame {
            id: frame
            screen: win.modelData
            crop: win.shot.capturing && win.mine ? win.shot.sel : Qt.rect(0, 0, 0, 0)

            // on the frame, so the drawings are in the grab; it gets the mouse while a tool
            // is picked, as the selecting MouseArea above steps aside
            Sketch {
                anchors.fill: parent
                owner: win.shot
                screen: win.name
                source: frame.view
                interactive: win.mine
                onRightClicked: win.shot.tool = ""
            }
        }

        Item {
            anchors.fill: parent
            visible: !win.shot.capturing

            Spotlight {
                anchors.fill: parent
                target: win.target
                instant: win.shot.dragging
                selected: win.mine && win.shot.hasSel
            }

            Loupe {
                source: frame.view
                point: Qt.point(win.mx, win.my)
                visible: win.mouseHere && (!win.shot.hasSel || win.shot.dragging)
            }

            MouseArea {
                anchors.fill: parent
                enabled: !(win.shot.tool && win.mine)
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: moving ? Qt.ClosedHandCursor : win.mine && win.shot.hasSel && inSel(mouseX, mouseY) ? Qt.OpenHandCursor : Qt.CrossCursor

                property point origin
                property rect startSel
                property bool moved: false
                property bool moving: false

                function inSel(x, y) {
                    const s = win.shot.sel;
                    return x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height;
                }

                function track(m) {
                    win.mx = m.x;
                    win.my = m.y;
                    win.shot.mouseScreen = win.name;
                }

                onPositionChanged: m => {
                    track(m);
                    if (!pressed) {
                        win.hover = win.shot.windowAt(win.wins, m.x, m.y);
                        return;
                    }
                    if (!moved && Math.hypot(m.x - origin.x, m.y - origin.y) < 4)
                        return;
                    moved = true;
                    if (moving) {
                        win.shot.sel = win.shot.clampRect(win.modelData, startSel.x + m.x - origin.x, startSel.y + m.y - origin.y, startSel.width, startSel.height);
                        return;
                    }
                    win.shot.dragging = true;
                    const x = Math.max(0, Math.min(win.width, m.x));
                    const y = Math.max(0, Math.min(win.height, m.y));
                    win.shot.select(win.name, Qt.rect(Math.min(origin.x, x), Math.min(origin.y, y), Math.abs(x - origin.x), Math.abs(y - origin.y)));
                }
                onPressed: m => {
                    track(m);
                    if (m.button === Qt.RightButton) {
                        if (win.shot.tool)
                            win.shot.tool = "";
                        else if (win.shot.hasSel)
                            win.shot.clear();
                        else
                            win.shot.close();
                        return;
                    }
                    origin = Qt.point(m.x, m.y);
                    moved = false;
                    moving = win.mine && win.shot.hasSel && inSel(m.x, m.y);
                    startSel = win.shot.sel;
                }
                onReleased: m => {
                    if (m.button !== Qt.LeftButton)
                        return;
                    win.shot.dragging = false;
                    const wasMoving = moving;
                    moving = false;
                    if (moved) {
                        if (!win.shot.hasSel || win.shot.sel.width < 3 || win.shot.sel.height < 3)
                            win.shot.clear();
                        return;
                    }
                    if (wasMoving)
                        return;
                    // a plain click: the window under it, or the whole monitor on bare desktop
                    win.hover = win.shot.windowAt(win.wins, m.x, m.y);
                    win.shot.select(win.name, win.hover ?? Qt.rect(0, 0, win.width, win.height));
                }
                onDoubleClicked: m => {
                    if (win.mine && win.shot.hasSel && inSel(m.x, m.y))
                        win.shot.finish();
                }
                onExited: win.mx = -1
            }

            ScreenshotToolbar {
                visible: win.focusedScreen
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32
                shot: win.shot
                onScreenRequested: win.selectScreen()
            }
        }

        KeyHelp {
            vimKeys: keys
        }
    }

    VimKeys {
        id: keys
        bindings: [
            { keys: "<CR>", desc: "copy + save", run: () => win.shot.finish() },
            { keys: "f", desc: "whole monitor", run: () => win.selectScreen() }
        ].concat(win.shot.tools.map(t => ({ keys: t.key, desc: t.label, run: () => win.shot.setTool(t.id) })), win.shot.inks.map((ink, i) => ({ keys: String(i + 1), desc: ink.name, run: () => win.shot.ink = ink.color })), [
            { keys: "u", desc: "undo", run: () => win.shot.undo() },
            { keys: "<C-z>", desc: "", run: () => win.shot.undo() },
            { keys: "h", desc: "move left", run: () => win.shot.nudge(-1, 0, 0, 0) },
            { keys: "l", desc: "move right", run: () => win.shot.nudge(1, 0, 0, 0) },
            { keys: "k", desc: "move up", run: () => win.shot.nudge(0, -1, 0, 0) },
            { keys: "j", desc: "move down", run: () => win.shot.nudge(0, 1, 0, 0) },
            { keys: "H", desc: "move left 10", run: () => win.shot.nudge(-10, 0, 0, 0) },
            { keys: "L", desc: "move right 10", run: () => win.shot.nudge(10, 0, 0, 0) },
            { keys: "K", desc: "move up 10", run: () => win.shot.nudge(0, -10, 0, 0) },
            { keys: "J", desc: "move down 10", run: () => win.shot.nudge(0, 10, 0, 0) },
            { keys: "<C-h>", desc: "narrower", run: () => win.shot.nudge(0, 0, -1, 0) },
            { keys: "<C-l>", desc: "wider", run: () => win.shot.nudge(0, 0, 1, 0) },
            { keys: "<C-k>", desc: "shorter", run: () => win.shot.nudge(0, 0, 0, -1) },
            { keys: "<C-j>", desc: "taller", run: () => win.shot.nudge(0, 0, 0, 1) },
            { keys: "<Esc>", desc: "stop drawing / clear / cancel", run: () => win.shot.tool ? win.shot.tool = "" : win.shot.hasSel ? win.shot.clear() : win.shot.close() },
            { keys: "q", desc: "cancel", run: () => win.shot.close() }
        ])
    }
}
