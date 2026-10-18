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
}
