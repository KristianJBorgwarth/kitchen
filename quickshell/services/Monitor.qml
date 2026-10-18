pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Monitor — system stats for the SystemMonitor window.
// Cheap /proc + /sys reads run all the time (every 200ms while the window is
// open, every second otherwise), so the graphs are already full when it opens;
// process list, sensors and disks are only polled while open (detailed = true).
// Every sample is timestamped in historyTimes so graphs plot by time, not count.
Singleton {
    id: root
    property bool detailed: false
    // sample rate while open is picked in the monitor header and remembered across restarts
    readonly property var intervalChoices: [100, 200, 500, 1000]
    readonly property int openInterval: settings.interval
    readonly property int interval: detailed ? openInterval : 1000
    readonly property int historyWindow: 60000 // ms shown in graphs
    property var historyTimes: []

    // system
    property string host: ""
    property string kernel: ""
    property string distro: ""
    property string uptime: ""
    property var load: [0, 0, 0]
    property int procCount: 0

    // cpu
    property string cpuModel: ""
    property real cpuUsage: 0
    property var coreUsage: []
    property real cpuFreqGHz: 0
    property real cpuTemp: 0
    property var cpuHistory: []

    // memory (GiB)
    property real memTotal: 0
    property real memUsed: 0
    property real memCache: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memUsage: memTotal > 0 ? memUsed / memTotal * 100 : 0
    property var memHistory: []

    // gpu: "amd", "nvidia" or "" when there's nothing we can read
    property string gpuVendor: ""
    property string gpuName: ""
    property real gpuUsage: 0
    property real gpuTemp: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property var gpuHistory: []

    // network + disk io (bytes/s)
    property string netIface: ""
    property real netRx: 0
    property real netTx: 0
    property var netRxHistory: []
    property var netTxHistory: []
    property real diskRead: 0
    property real diskWrite: 0
    property var diskReadHistory: []
    property var diskWriteHistory: []

    // detailed only
    property var processes: []  // [{pid, cpu, mem, name}]
    property var sensors: []    // [{name, temp}]
    property var mounts: []     // [{mount, used, total}] in GiB

    property var _prevCpu: null
    property var _prevNet: null
    property var _prevDisk: null
    property real _prevTime: 0
    property real _lastFreq: 0
    property real _lastNvidia: 0

    // appends v and drops whatever fell out of the time window (drop = count to cut)
    function setOpenInterval(ms: int): void {
        settings.interval = ms;
    }

    FileView {
        // the file only exists once a setting has been changed
        printErrors: false
        path: Quickshell.statePath("monitor.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property int interval: 200
        }
    }

    function push(arr, v, drop) {
        const out = arr.slice(drop);
        out.push(v);
        return out;
    }

    function fmtRate(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB/s";
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024)
            return (b / 1024).toFixed(0) + " KB/s";
        return Math.round(b) + " B/s";
    }

    function fmtUptime(s) {
        const d = Math.floor(s / 86400);
        const h = Math.floor(s % 86400 / 3600);
        const m = Math.floor(s % 3600 / 60);
        return (d > 0 ? d + "d " : "") + h + "h " + m + "m";
    }

    function read(fv) {
        fv.reload();
        return fv.text();
    }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: netFile; path: "/proc/net/dev"; blockLoading: true }
    FileView { id: diskFile; path: "/proc/diskstats"; blockLoading: true }
    FileView { id: loadFile; path: "/proc/loadavg"; blockLoading: true }
    FileView { id: uptimeFile; path: "/proc/uptime"; blockLoading: true }
    FileView { id: cpuinfoFile; path: "/proc/cpuinfo"; blockLoading: true }
    FileView { id: gpuBusyFile; blockLoading: true }
    FileView { id: vramUsedFile; blockLoading: true }

    function sampleCpu() {
        const lines = read(statFile).split("\n").filter(l => l.startsWith("cpu"));
        const cur = lines.map(l => {
            const p = l.trim().split(/\s+/).slice(1, 9).map(Number);
            return { idle: p[3] + p[4], total: p.reduce((a, b) => a + b, 0) };
        });
        if (_prevCpu && _prevCpu.length === cur.length) {
            const usage = cur.map((c, i) => {
                const dt = c.total - _prevCpu[i].total;
                return dt > 0 ? 100 * (1 - (c.idle - _prevCpu[i].idle) / dt) : 0;
            });
            cpuUsage = usage[0];
            coreUsage = usage.slice(1);
        }
        _prevCpu = cur;
    }

    function sampleMem() {
        const m = {};
        for (const l of read(memFile).split("\n")) {
            const p = l.split(/:\s+/);
            if (p.length === 2)
                m[p[0]] = parseInt(p[1]) / 1048576;
        }
        memTotal = m.MemTotal ?? 0;
        memUsed = memTotal - (m.MemAvailable ?? 0);
        memCache = (m.Buffers ?? 0) + (m.Cached ?? 0) + (m.SReclaimable ?? 0) - (m.Shmem ?? 0);
        swapTotal = m.SwapTotal ?? 0;
        swapUsed = swapTotal - (m.SwapFree ?? 0);
    }

    function sampleNet(dt) {
        let rx = 0, tx = 0, best = "", bestTotal = -1;
        for (const l of read(netFile).split("\n").slice(2)) {
            const [name, rest] = l.split(":");
            if (!rest || name.trim() === "lo")
                continue;
            const p = rest.trim().split(/\s+/).map(Number);
            rx += p[0];
            tx += p[8];
            if (p[0] + p[8] > bestTotal) {
                bestTotal = p[0] + p[8];
                best = name.trim();
            }
        }
        netIface = best;
        if (_prevNet) {
            netRx = Math.max(0, rx - _prevNet.rx) / dt;
            netTx = Math.max(0, tx - _prevNet.tx) / dt;
        }
        _prevNet = { rx, tx };
    }

    function sampleDisk(dt) {
        let r = 0, w = 0;
        for (const l of read(diskFile).split("\n")) {
            const p = l.trim().split(/\s+/);
            // whole disks only, partitions would double count
            if (p.length < 10 || !/^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|mmcblk\d+)$/.test(p[2]))
                continue;
            r += Number(p[5]) * 512;
            w += Number(p[9]) * 512;
        }
        if (_prevDisk) {
            diskRead = Math.max(0, r - _prevDisk.r) / dt;
            diskWrite = Math.max(0, w - _prevDisk.w) / dt;
        }
        _prevDisk = { r, w };
    }

    function sampleSystem() {
        const l = read(loadFile).trim().split(/\s+/);
        load = [Number(l[0]), Number(l[1]), Number(l[2])];
        procCount = parseInt(l[3].split("/")[1]);
        uptime = fmtUptime(parseInt(read(uptimeFile)));
    }

    function sampleFreq() {
        const mhz = read(cpuinfoFile).split("\n").filter(l => l.startsWith("cpu MHz")).map(l => Number(l.split(":")[1]));
        if (mhz.length > 0)
            cpuFreqGHz = Math.max(...mhz) / 1000;
    }

    function sampleAmdGpu() {
        gpuUsage = parseInt(read(gpuBusyFile)) || 0;
        vramUsed = (parseInt(read(vramUsedFile)) || 0) / 1073741824;
    }

    function tick() {
        const now = Date.now();
        // the first sample only primes the deltas
        const first = _prevTime === 0;
        const dt = first ? 1 : (now - _prevTime) / 1000;
        _prevTime = now;

        sampleCpu();
        sampleMem();
        sampleNet(dt);
        sampleDisk(dt);
        sampleSystem();
        if (gpuVendor === "amd")
            sampleAmdGpu();
        // nvidia-smi is a process spawn; once a second is plenty
        else if (gpuVendor === "nvidia" && now - _lastNvidia >= 1000 && !nvidiaProc.running) {
            _lastNvidia = now;
            nvidiaProc.running = true;
        }
        if (detailed && now - _lastFreq >= 1000) {
            _lastFreq = now;
            sampleFreq();
        }

        if (first)
            return;
        let drop = 0;
        while (drop < historyTimes.length && now - historyTimes[drop] > historyWindow)
            drop++;
        historyTimes = push(historyTimes, now, drop);
        cpuHistory = push(cpuHistory, cpuUsage, drop);
        memHistory = push(memHistory, memUsage, drop);
        gpuHistory = push(gpuHistory, gpuUsage, drop);
        netRxHistory = push(netRxHistory, netRx, drop);
        netTxHistory = push(netTxHistory, netTx, drop);
        diskReadHistory = push(diskReadHistory, diskRead, drop);
        diskWriteHistory = push(diskWriteHistory, diskWrite, drop);
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    // one-time facts + gpu detection
    Process {
        running: true
        command: ["sh", "-c", "cat /proc/sys/kernel/hostname /proc/sys/kernel/osrelease; . /etc/os-release; echo \"$PRETTY_NAME\"; grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("\n");
                root.host = p[0];
                root.kernel = p[1];
                root.distro = p[2];
                root.cpuModel = (p[3] ?? "").trim().replace(/\s+w\/.*$/, "").replace(/\s+\d+-Core Processor$/, "");
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "d=$(dirname $(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1) 2>/dev/null); if [ -n \"$d\" ]; then echo amd; echo \"$d\"; cat \"$d/mem_info_vram_total\" 2>/dev/null || echo 0; elif command -v nvidia-smi >/dev/null; then echo nvidia; nvidia-smi --query-gpu=name --format=csv,noheader | head -1; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("\n");
                if (p[0] === "amd") {
                    gpuBusyFile.path = p[1] + "/gpu_busy_percent";
                    vramUsedFile.path = p[1] + "/mem_info_vram_used";
                    root.vramTotal = parseInt(p[2]) / 1073741824;
                    root.gpuName = "AMD Radeon";
                    root.gpuVendor = "amd";
                } else if (p[0] === "nvidia") {
                    root.gpuName = p[1] ?? "NVIDIA";
                    root.gpuVendor = "nvidia";
                }
            }
        }
    }

    Process {
        id: nvidiaProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.split("\n")[0].split(",").map(s => Number(s.trim()));
                root.gpuUsage = p[0] || 0;
                root.gpuTemp = p[1] || 0;
                root.vramUsed = (p[2] || 0) / 1024;
                root.vramTotal = (p[3] || 0) / 1024;
            }
        }
    }

    // sensors: run always (slowly) so the cpu/gpu temps are there; full list is shown when detailed
    Process {
        id: sensorsProc
        command: [Quickshell.shellPath("scripts/sensors.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = { k10temp: "CPU", coretemp: "CPU", zenpower: "CPU", cpu_thermal: "CPU", amdgpu: "GPU", nouveau: "GPU", nvme: "NVMe", spd5118: "RAM", jc42: "RAM", acpitz: "ACPI", iwlwifi_1: "Wi-Fi", mt7921_phy0: "Wi-Fi", nvidia: "GPU" };
                const seen = {};
                const list = [];
                let cpu = 0, gpu = 0;
                for (const l of this.text.trim().split("\n")) {
                    const [chip, label, t] = l.split("|");
                    const temp = Number(t);
                    if (!chip || !(temp > 0))
                        continue;
                    if (/^(Tctl|Tdie|Package id 0)$/.test(label) || (chip === "cpu_thermal" && !cpu))
                        cpu = temp;
                    if (chip === "amdgpu" && label === "edge")
                        gpu = temp;
                    // nvme exposes several sub-sensors; Composite is the one that matters
                    if (chip === "nvme" && label !== "Composite")
                        continue;
                    // coretemp: keep the package, skip per-core lines
                    if (chip === "coretemp" && label.startsWith("Core"))
                        continue;
                    let name = names[chip] ?? (chip.startsWith("r81") || chip.startsWith("e1000") ? "Ethernet" : chip.startsWith("iwl") || chip.startsWith("mt7") ? "Wi-Fi" : chip);
                    seen[name] = (seen[name] ?? 0) + 1;
                    if (seen[name] > 1)
                        name += " " + seen[name];
                    list.push({ name, temp });
                }
                root.cpuTemp = cpu;
                if (root.gpuVendor !== "nvidia")
                    root.gpuTemp = gpu;
                root.sensors = list;
            }
        }
    }

    Timer {
        interval: root.detailed ? 2000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sensorsProc.running = true
    }

    Process {
        id: procsProc
        command: [Quickshell.shellPath("scripts/top_procs.sh"), "8"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.processes = this.text.trim().split("\n").filter(l => l).map(l => {
                    const p = l.split(" ");
                    return { pid: p[0], cpu: Number(p[1]), mem: Number(p[2]), name: p.slice(3).join(" ").replace(/_/g, " ") };
                });
            }
        }
    }

    Process {
        id: dfProc
        command: ["sh", "-c", "df -kP -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay -x fuse.portal 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const list = [];
                for (const l of this.text.trim().split("\n")) {
                    const p = l.trim().split(/\s+/);
                    // btrfs subvolumes repeat the same device; /boot-ish mounts are noise
                    if (p.length < 6 || seen[p[0]] || /^\/(boot|efi)/.test(p[5]))
                        continue;
                    seen[p[0]] = true;
                    list.push({ mount: p[5], used: Number(p[2]) / 1048576, total: Number(p[1]) / 1048576 });
                }
                root.mounts = list;
            }
        }
    }

    Timer {
        interval: 2000
        running: root.detailed
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procsProc.running = true;
            if (!dfProc.running)
                dfProc.running = true;
        }
    }
}
