pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// cliphist history. Pasting goes through wtype (a virtual keyboard): Wayland gives apps
// no other way to type into another window. Without wtype, picking an entry only copies.
Singleton {
    id: root
    // [{ line, id, text, image }]; `line` is cliphist's own "id<TAB>preview" row
    property var entries: []
    property bool canPaste: false

    // cliphist is often a `go install` in ~/go/bin, which isn't on the shell's PATH
    readonly property string env: 'PATH="$PATH:$HOME/go/bin"; '

    function refresh(): void {
        listProc.running = true;
    }

    Process {
        id: listProc
        command: ["sh", "-c", root.env + "cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = this.text.split("\n").filter(l => l).map(line => {
                    const tab = line.indexOf("\t");
                    const text = line.slice(tab + 1);
                    const img = text.match(/^\[\[ binary data (.+) \]\]$/);
                    return { line, id: line.slice(0, tab), text: img ? "Image  ·  " + img[1] : text, image: !!img };
                });
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v wtype"]
        onExited: code => root.canPaste = code === 0
    }

    Process {
        id: actProc
    }

    function copy(entry): void {
        actProc.command = ["sh", "-c", root.env + 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", entry.line];
        actProc.running = true;
    }

    // copies, then sends the paste shortcut once focus is back in the app
    function paste(entry, terminal: bool): void {
        const keys = terminal ? "wtype -M ctrl -M shift -k v -m shift -m ctrl" : "wtype -M ctrl -k v -m ctrl";
        actProc.command = ["sh", "-c", root.env + 'printf "%s" "$1" | cliphist decode | wl-copy && sleep 0.15 && ' + keys, "sh", entry.line];
        actProc.running = true;
    }

    function remove(entry): void {
        actProc.command = ["sh", "-c", root.env + 'printf "%s" "$1" | cliphist delete', "sh", entry.line];
        actProc.running = true;
        entries = entries.filter(e => e !== entry);
    }
}
