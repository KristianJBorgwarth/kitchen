import Quickshell
import Quickshell.Io
import qs.modules.widgets

Scope {
    IpcHandler {
        target: "performance"

        function toggle(): void {
            Performance.toggle();
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            ControlCenter.toggle();
        }
    }

    IpcHandler {
        target: "tray"

        function toggle(): void {
            TrayPanel.toggle();
        }
    }
}
