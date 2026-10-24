import Quickshell
import Quickshell.Io
import qs.core
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
        target: "pomodoro"

        function toggle(): void {
            PomodoroPanel.toggle();
        }
        function startpause(): void {
            Pomodoro.toggle(Pomodoro.target);
        }
        function skip(): void {
            Pomodoro.skip(Pomodoro.target);
        }
        function reset(): void {
            Pomodoro.reset(Pomodoro.target);
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
        target: "wallpaper"

        function toggle(): void {
            WallpaperPicker.toggle();
        }

        function random(): void {
            Wallpaper.random();
        }
    }

    IpcHandler {
        target: "theme"

        // dark ↔ light
        function toggle(): void {
            Main.theme.toggle();
        }
    }

    IpcHandler {
        target: "screenshot"

        // freeze the monitors, then pick a window, region or monitor and draw on it
        function start(): void {
            Screenshot.start();
        }
        // the focused monitor, straight to the clipboard and ~/Pictures/Screenshots
        function screen(): void {
            Screenshot.instant = "screen";
            Screenshot.start();
        }
    }

    IpcHandler {
        target: "draw"

        // draw on the screen; while drawing, clear and stop
        function toggle(): void {
            Draw.toggle();
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
