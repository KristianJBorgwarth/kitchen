pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pomodoro — focus / short break / long break with a session history.
// Every phase has its own timer. Looking at a phase (the tabs) never touches a timer: a timer
// only stops when you pause, reset or skip it, or when it runs out. Running timers are stored
// as end timestamps, so they survive quickshell reloads.
Singleton {
    id: root

    // The state lives in plain properties here and is copied to the JSON file on change and
    // back on load; JsonAdapter's own properties don't reliably notify bindings.
    readonly property var phases: ["focus", "short", "long"]
    // the phase shown in the panel: "focus" | "short" | "long"
    property string phase: "focus"
    // phase -> end time (ms since epoch) of the timers that are running
    property var ends: ({})
    // phase -> ms left, for timers that were paused
    property var left: ({})
    // focus sessions finished in the current cycle
    property int cycle: 0
    property string label: ""
    // [{ start (ms), minutes, label, completed }]
    property var history: []

    property int focusMin: 25
    property int shortMin: 5
    property int longMin: 15
    property int sessionsBeforeLong: 4
    property int dailyGoal: 8
    property bool autoStart: true
    property bool sound: true

    property bool loaded: false

    // ms since epoch, refreshed every second while a timer runs
    property double now: Date.now()

    // the shown phase
    readonly property int totalMs: minutesFor(phase) * 60000
    readonly property bool running: (ends[phase] ?? 0) > 0
    readonly property int remainingMs: remaining(phase)
    readonly property real progress: totalMs > 0 ? 1 - remainingMs / totalMs : 0
    readonly property bool paused: !running && remainingMs < totalMs

    // the timer the bar shows and the shortcuts act on: the running one that ends first,
    // else a paused one, else the shown phase (nothing to show)
    readonly property bool anyRunning: phases.some(p => (ends[p] ?? 0) > 0)
    readonly property string barPhase: {
        let best = "";
        for (const p of phases) {
            if ((ends[p] ?? 0) > 0 && (best === "" || ends[p] < ends[best]))
                best = p;
        }
        if (best !== "")
            return best;
        if (hasProgress(phase))
            return phase;
        return phases.find(p => hasProgress(p)) ?? "";
    }
    readonly property bool active: barPhase !== ""
    readonly property string target: active ? barPhase : phase
    readonly property bool targetRunning: (ends[target] ?? 0) > 0
    readonly property int targetRemainingMs: remaining(target)

    readonly property var today: statsFor(dayKey(now))
    readonly property var week: {
        const out = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date(now);
            d.setDate(d.getDate() - i);
            const s = statsFor(dayKey(d.getTime()));
            out.push({ day: Qt.locale().dayName(d.getDay(), Locale.NarrowFormat), count: s.count, minutes: s.minutes, today: i === 0 });
        }
        return out;
    }
    // consecutive days with a finished session, ending today (or yesterday if none yet today)
    readonly property int streak: {
        let n = 0;
        const d = new Date(now);
        if (statsFor(dayKey(d.getTime())).count === 0)
            d.setDate(d.getDate() - 1);
        while (statsFor(dayKey(d.getTime())).count > 0) {
            n++;
            d.setDate(d.getDate() - 1);
        }
        return n;
    }

    function minutesFor(p) {
        return p === "focus" ? focusMin : p === "short" ? shortMin : longMin;
    }

    function dayKey(ms) {
        return Qt.formatDate(new Date(ms), "yyyy-MM-dd");
    }

    function statsFor(key) {
        let count = 0, minutes = 0;
        for (const h of history) {
            if (h.completed && dayKey(h.start) === key) {
                count++;
                minutes += h.minutes;
            }
        }
        return { count, minutes };
    }

    function fmt(ms) {
        const s = Math.ceil(ms / 1000);
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }

    function isRunning(p) {
        return (ends[p] ?? 0) > 0;
    }

    function remaining(p) {
        const total = minutesFor(p) * 60000;
        if (isRunning(p))
            return Math.max(0, Math.round(ends[p] - now));
        const v = left[p];
        return v === undefined ? total : Math.min(v, total);
    }

    // started and not finished: running, or paused part-way
    function hasProgress(p) {
        return isRunning(p) || remaining(p) < minutesFor(p) * 60000;
    }

    // Sets a phase's timer to running (endMs) or to paused/idle (leftMs; null for a full one).
    // The order keeps the remaining time right at every step, so the ring never flashes.
    function setTimer(p, endMs, leftMs) {
        const e = Object.assign({}, ends);
        const l = Object.assign({}, left);
        if (endMs === null)
            delete e[p];
        else
            e[p] = endMs;
        if (leftMs === null)
            delete l[p];
        else
            l[p] = leftMs;
        if (endMs !== null) {
            ends = e;
            left = l;
        } else {
            left = l;
            ends = e;
        }
    }

    function start(p = phase) {
        if (isRunning(p))
            return;
        now = Date.now();
        setTimer(p, now + remaining(p), null);
    }

    function pause(p = phase) {
        if (!isRunning(p))
            return;
        now = Date.now();
        setTimer(p, null, Math.max(0, ends[p] - now));
    }

    function toggle(p = phase) {
        if (isRunning(p))
            pause(p);
        else
            start(p);
    }

    // back to the full length, stopped
    function reset(p = phase) {
        logInterrupted(p);
        setTimer(p, null, null);
    }

    // on to the next phase without counting this one
    function skip(p = phase) {
        logInterrupted(p);
        setTimer(p, null, null);
        advance(p, false);
    }

    // only changes what the panel shows; no timer is touched
    function setPhase(p) {
        phase = p;
    }

    function setLabel(text) {
        label = text;
    }

    function setSetting(key, value) {
        const limits = { focusMin: [1, 120], shortMin: [1, 60], longMin: [1, 120], sessionsBeforeLong: [2, 8], dailyGoal: [1, 20] };
        if (limits[key])
            value = Math.max(limits[key][0], Math.min(limits[key][1], value));
        root[key] = value;
    }

    function removeEntry(entry) {
        history = history.filter(h => !(h.start === entry.start && h.minutes === entry.minutes && h.completed === entry.completed));
    }

    function clearHistory() {
        history = [];
    }

    function logInterrupted(p) {
        const done = minutesFor(p) * 60000 - remaining(p);
        if (p === "focus" && done >= 60000)
            record(false, Math.round(done / 60000));
    }

    function record(completed, minutes) {
        const entry = { start: Date.now() - minutes * 60000, minutes, label, completed };
        history = history.concat([entry]).slice(-500);
    }

    // `finished`: the phase ran to the end
    function advance(p, finished) {
        let next;
        if (p === "focus") {
            if (finished)
                cycle = cycle + 1;
            if (cycle >= sessionsBeforeLong) {
                next = "long";
                cycle = 0;
            } else {
                next = "short";
            }
        } else {
            next = "focus";
        }
        // follow along only if that's what you were looking at
        if (phase === p)
            phase = next;
        if (finished && autoStart)
            start(next);
        return next;
    }

    function complete(p) {
        // the timer is gone before anything else, so a phase completes exactly once
        setTimer(p, null, null);
        if (p === "focus")
            record(true, focusMin);
        const next = advance(p, true);
        const msg = p === "focus" ? ["Focus session done", "Time for a " + (next === "long" ? "long" : "short") + " break (" + minutesFor(next) + " min)."] : ["Break over", "Back to focus (" + focusMin + " min)."];
        notifyProc.command = ["notify-send", "-a", "Pomodoro", "-i", Qt.resolvedUrl("../assets/pomodoro.svg").toString().replace("file://", ""), msg[0], msg[1]];
        notifyProc.running = true;
        if (sound)
            soundProc.running = true;
    }

    function tick() {
        now = Date.now();
        for (const p of phases) {
            if (isRunning(p) && now >= ends[p])
                complete(p);
        }
    }

    Process {
        id: notifyProc
    }
    Process {
        id: soundProc
        command: ["pw-play", Qt.resolvedUrl("../assets/pomodoro-chime.wav").toString().replace("file://", "")]
    }

    SystemClock {
        enabled: root.anyRunning
        precision: SystemClock.Seconds
        onDateChanged: root.tick()
    }

    readonly property var snapshot: ({
            phase, ends, left, cycle, label, history,
            focusMin, shortMin, longMin, sessionsBeforeLong, dailyGoal, autoStart, sound
        })
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
        path: Quickshell.statePath("pomodoro.json")
        onAdapterUpdated: writeAdapter()
        onLoaded: root.restore()
        onLoadFailed: root.loaded = true

        JsonAdapter {
            id: store
            property string phase: "focus"
            property var ends: ({})
            property var left: ({})
            property int cycle: 0
            property string label: ""
            property int focusMin: 25
            property int shortMin: 5
            property int longMin: 15
            property int sessionsBeforeLong: 4
            property int dailyGoal: 8
            property bool autoStart: true
            property bool sound: true
            property var history: []
        }
    }
}
