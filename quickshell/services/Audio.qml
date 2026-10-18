pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio — PipeWire default sink (output) and source (mic), plus every device and
// per-app stream while `detailed` (the control center is open).
Singleton {
    id: root
    property bool detailed: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // isSink/isStream are known up front; properties like media.class only fill in
    // once a node is tracked, so they can't be used to pick what to track
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream)
    // apps playing sound. For streams isSink is from PipeWire's side: playback streams
    // are what devices pull from, so they're the "sink" ones (capture streams like cava aren't)
    readonly property var streams: nodes.filter(n => n.isStream && n.isSink)

    // nodes must be tracked for their audio properties to be live
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.detailed ? root.sinks.concat(root.sources, root.streams) : [])
    }

    function label(n) {
        if (!n)
            return "";
        const p = n.properties ?? {};
        return p["application.name"] || n.description || n.nickname || n.name;
    }

    function setDefault(n) {
        if (n.isSink)
            Pipewire.preferredDefaultAudioSink = n;
        else
            Pipewire.preferredDefaultAudioSource = n;
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
