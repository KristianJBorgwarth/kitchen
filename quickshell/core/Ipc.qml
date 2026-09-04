import Quickshell.Io
import qs.modules.widgets

IpcHandler {
    target: "performance"

    function toggle(): void {
        Performance.toggle();
    }
}
