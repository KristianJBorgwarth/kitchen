pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.core
import qs.services
import "components"

// Lock screen over sway's ext-session-lock: until unlocked, the compositor shows nothing
// else and stays locked even if quickshell dies (recover from a TTY by starting another
// locker, e.g. swaylock). The password is checked by PAM's "login" config.
Scope {
    id: root
    readonly property bool locked: sessionLock.locked
    // the monitor that gets the clock and password box, e.g. "DP-2"; empty = the one that's
    // focused when locking. Sway has to cover every monitor, so the rest show the wallpaper
    property string preferredScreen: ""
    property string mainScreen: ""
    property string password: ""
    property bool failed: false
    readonly property bool busy: pam.active
    property string message: ""

    function lock(): void {
        password = "";
        failed = false;
        message = "";
        ModalHost.current?.hide();
        mainScreen = preferredScreen || I3.focusedMonitor?.name || "";
        sessionLock.locked = true;
    }

    // lock first, so the machine wakes up locked
    function suspend(): void {
        lock();
        suspendLater.restart();
    }

    Timer {
        id: suspendLater
        interval: 400
        onTriggered: Session.suspend()
    }

    function tryUnlock(): void {
        if (password === "" || pam.active)
            return;
        failed = false;
        pam.start();
    }

    onPasswordChanged: if (password !== "") failed = false

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (responseRequired)
                respond(root.password);
            else if (!messageIsError)
                root.message = message;
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                root.message = "";
            } else {
                root.failed = true;
            }
            root.password = "";
        }
        onError: root.message = "Couldn't check the password (PAM error)"
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: Main.theme.colBg

            LockContent {
                anchors.fill: parent
                lock: root
                main: !root.mainScreen || surface.screen?.name === root.mainScreen
            }
        }
    }

    // ── preview: the same screen in an ordinary overlay, nothing actually locked ──
    property bool previewing: false

    function preview(): void {
        password = "";
        failed = false;
        previewing = true;
    }

    // it takes the keyboard, so it never lingers
    Timer {
        running: root.previewing
        interval: 8000
        onTriggered: root.previewing = false
    }

    LazyLoader {
        active: root.previewing

        PanelWindow {
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            LockContent {
                anchors.fill: parent
                lock: root
                preview: true
                onClosePreview: {
                    root.password = "";
                    root.previewing = false;
                }
            }
        }
    }
}
