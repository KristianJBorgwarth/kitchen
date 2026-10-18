pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio — default PipeWire sink (output) and source (mic)
Singleton {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // nodes must be tracked for their audio properties to be live
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function setVolume(node: PwNode, value: real): void {
        if (node?.ready && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute(node: PwNode): void {
        if (node?.ready && node.audio)
            node.audio.muted = !node.audio.muted;
    }
}
