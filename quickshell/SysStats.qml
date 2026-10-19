pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU and memory use from /proc, every 3 seconds, or every second while the
// system panel is open.
Singleton {
    id: root

    property bool fast: false

    // Total first, then each core, in percent.
    property var cpu: []
    property var previous: []

    // In KiB.
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property int memPercent: memTotal > 0 ? Math.round(100 * memUsed / memTotal) : -1

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const samples = text().split("\n")
                .filter(line => line.startsWith("cpu"))
                .map(line => {
                    const fields = line.trim().split(/\s+/).slice(1).map(Number);
                    return { idle: fields[3] + fields[4], total: fields.reduce((sum, value) => sum + value, 0) };
                });
            if (root.previous.length === samples.length)
                root.cpu = samples.map((sample, i) => {
                    const total = sample.total - root.previous[i].total;
                    return total > 0 ? Math.round(100 * (1 - (sample.idle - root.previous[i].idle) / total)) : 0;
                });
            root.previous = samples;
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kib = {};
            for (const line of text().split("\n")) {
                const match = line.match(/^(\w+):\s+(\d+)/);
                if (match)
                    kib[match[1]] = Number(match[2]);
            }
            root.memTotal = kib.MemTotal;
            root.memUsed = kib.MemTotal - kib.MemAvailable;
            root.swapTotal = kib.SwapTotal;
            root.swapUsed = kib.SwapTotal - kib.SwapFree;
        }
    }

    Timer {
        interval: root.fast ? 1000 : 3000
        running: true
        repeat: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }
}
