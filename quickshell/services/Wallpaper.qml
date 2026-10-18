pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The desktop wallpaper: the images in assets/wallpaper, one drawn behind everything on every
// monitor and crossfaded on change. The choice is remembered; the first run takes over the
// one waypaper had set.
Singleton {
    id: root
    // absolute paths, sorted by name
    property var files: []
    readonly property string path: settings.path || seed || (files[0] ?? "")
    readonly property string url: path ? "file://" + path : ""
    readonly property string seed: {
        const m = legacy.text().match(/^wallpaper\s*=\s*(.+)$/m);
        return m ? m[1].trim().replace(/^~/, Quickshell.env("HOME")) : "";
    }

    function set(p: string): void {
        settings.path = p;
    }

    function random(): void {
        const others = files.filter(f => f !== path);
        if (others.length > 0)
            set(others[Math.floor(Math.random() * others.length)]);
    }

    FileView {
        printErrors: false
        path: Quickshell.statePath("wallpaper.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property string path: ""
        }
    }

    FileView {
        id: legacy
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        printErrors: false
    }

    // the config is usually reached through a symlink, so resolve it to find the repo's assets
    Process {
        running: true
        command: ["sh", "-c", "cd \"$(readlink -f \"$1\")/../assets/wallpaper\" 2>/dev/null && find \"$PWD\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort", "sh", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(l => l !== "")
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-wallpaper"

            // the previous picture stays underneath while the new one fades in
            Image {
                id: back
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
            }

            Image {
                id: front
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: root.url
                opacity: 0

                onSourceChanged: {
                    back.source = shown;
                    opacity = 0;
                }
                onStatusChanged: {
                    if (status === Image.Ready) {
                        fade.restart();
                        shown = source;
                    }
                }
                property url shown: ""

                NumberAnimation on opacity {
                    id: fade
                    running: false
                    from: 0
                    to: 1
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
