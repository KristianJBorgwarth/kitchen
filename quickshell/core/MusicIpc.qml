import Quickshell.Io
import qs.modules.widgets

IpcHandler {
    target: "music"

    function toggle(): void {
        MusicPlayer.toggle();
    }
}
