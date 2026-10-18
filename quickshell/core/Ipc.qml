import Quickshell
import Quickshell.Io
import qs.modules.widgets
import qs.services

Scope {
    IpcHandler {
        target: "performance"

        function toggle(): void {
            SystemMonitor.toggle();
        }

        // sample interval (ms) used while the monitor is open
        function setInterval(ms: int): void {
            Monitor.setOpenInterval(ms);
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            ControlCenter.toggle();
        }

        // open on a tab: sound, network or bluetooth
        function open(tab: string): void {
            ControlCenter.openTab(tab);
            if (!ControlCenter.opened)
                ControlCenter.show();
        }
    }

    IpcHandler {
        target: "tray"

        function toggle(): void {
            TrayPanel.toggle();
        }
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            Cheatsheet.toggle();
        }
    }

    IpcHandler {
        target: "switcher"

        function toggle(): void {
            Switcher.toggle();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Launcher.toggle();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            ClipboardPicker.toggle();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }
        // the lock screen without locking, to look at it
        function preview(): void {
            Lock.preview();
        }
    }

    // media keys
    IpcHandler {
        target: "osd"

        function volumeUp(): void {
            Osd.volume(0.05);
        }
        function volumeDown(): void {
            Osd.volume(-0.05);
        }
        function volumeMute(): void {
            Osd.toggleMute();
        }
        function micMute(): void {
            Osd.toggleMicMute();
        }
        function brightnessUp(): void {
            Osd.brightness(0.05);
        }
        function brightnessDown(): void {
            Osd.brightness(-0.05);
        }
    }
}
