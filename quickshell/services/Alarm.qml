pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A countdown timer or an alarm at a time of day. Runs are stored as end timestamps, so they survive reloads.
Singleton {
    id: root

    property string mode: "timer" // "timer" | "alarm"
    property int minutes: 10
    property int alarmAt: 7 * 60 // minute of the day
    property double endsAt: 0 // ms since epoch while running
    property double leftMs: 0 // while paused
    property double totalMs: 0 // length of the current run

    property bool loaded: false
    property double now: Date.now()

    readonly property bool running: endsAt > 0
    readonly property bool paused: !running && leftMs > 0
    readonly property bool active: running || paused
    readonly property double remainingMs: running ? Math.max(0, endsAt - now) : paused ? leftMs : mode === "timer" ? minutes * 60000 : untilAlarm()
    readonly property real progress: active && totalMs > 0 ? 1 - remainingMs / totalMs : 0

    function untilAlarm() {
        const d = new Date(now);
        d.setHours(Math.floor(alarmAt / 60), alarmAt % 60, 0, 0);
        if (d.getTime() <= now)
            d.setDate(d.getDate() + 1);
        return d.getTime() - now;
    }

    function fmt(ms) {
        const s = Math.ceil(ms / 1000);
        const h = Math.floor(s / 3600);
        const mm = String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + mm : mm;
    }

    function clock(minuteOfDay) {
        return String(Math.floor(minuteOfDay / 60)).padStart(2, "0") + ":" + String(minuteOfDay % 60).padStart(2, "0");
    }

    function setMode(m) {
        if (!active)
            mode = m;
    }

    // timer: minutes; alarm: minutes of the time, wrapping at midnight
    function adjust(d) {
        if (active)
            return;
        now = Date.now();
        if (mode === "timer")
            minutes = Math.max(1, Math.min(999, minutes + d));
        else
            alarmAt = ((alarmAt + d) % 1440 + 1440) % 1440;
    }

    function setMinutes(m) {
        if (active)
            return;
        mode = "timer";
        minutes = m;
    }

    function start() {
        if (running)
            return;
        now = Date.now();
        if (!paused)
            totalMs = remainingMs;
        endsAt = now + remainingMs;
        leftMs = 0;
    }

    // an alarm can't be paused; it's cancelled instead
    function pause() {
        if (!running)
            return;
        if (mode === "alarm") {
            reset();
            return;
        }
        now = Date.now();
        leftMs = Math.max(1, endsAt - now);
        endsAt = 0;
    }

    function toggle() {
        if (running)
            pause();
        else
            start();
    }

    function reset() {
        endsAt = 0;
        leftMs = 0;
        totalMs = 0;
        now = Date.now();
    }

    function fire() {
        const title = mode === "timer" ? "Timer done" : "Alarm";
        const body = mode === "timer" ? fmt(totalMs) + " is up." : "It's " + clock(alarmAt) + ".";
        reset();
        notifyProc.command = ["notify-send", "-a", "Alarm", "-u", "critical", "-i", Qt.resolvedUrl("../assets/alarm.svg").toString().replace("file://", ""), title, body];
        notifyProc.running = true;
        soundProc.running = true;
    }

    function tick() {
        now = Date.now();
        if (running && now >= endsAt)
            fire();
    }

    Process {
        id: notifyProc
    }
    Process {
        id: soundProc
        command: ["pw-play", Qt.resolvedUrl("../assets/alarm-chime.wav").toString().replace("file://", "")]
    }

    SystemClock {
        enabled: root.running || root.mode === "alarm"
        precision: SystemClock.Seconds
        onDateChanged: root.tick()
    }

    readonly property var snapshot: ({ mode, minutes, alarmAt, endsAt, leftMs, totalMs })
    onSnapshotChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 100
        onTriggered: {
            for (const k in root.snapshot)
                store[k] = root.snapshot[k];
        }
    }

    function restore() {
        if (loaded)
            return;
        for (const k in root.snapshot)
            root[k] = store[k];
        loaded = true;
        tick();
    }

    FileView {
        printErrors: false
        watchChanges: false
        path: Quickshell.statePath("alarm.json")
        onAdapterUpdated: writeAdapter()
        onLoaded: root.restore()
        onLoadFailed: root.loaded = true

        JsonAdapter {
            id: store
            property string mode: "timer"
            property int minutes: 10
            property int alarmAt: 420
            property double endsAt: 0
            property double leftMs: 0
            property double totalMs: 0
        }
    }
}
