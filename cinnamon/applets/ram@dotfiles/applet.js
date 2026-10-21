const Applet = imports.ui.applet;
const GLib = imports.gi.GLib;
const Util = imports.misc.util;

// Same numbers as the Sway bar (quickshell/SysStats.qml): used is MemTotal
// minus MemAvailable, read every 3 seconds, red from 81%.
const INTERVAL_SECONDS = 3;
const CRITICAL_PERCENT = 81;
const RED = "#fb4934";

function readMeminfo() {
    const [ok, bytes] = GLib.file_get_contents("/proc/meminfo");
    const kib = {};
    if (!ok)
        return kib;
    for (const line of new TextDecoder().decode(bytes).split("\n")) {
        const match = line.match(/^(\w+):\s+(\d+)/);
        if (match)
            kib[match[1]] = Number(match[2]);
    }
    return kib;
}

function gib(kib) {
    return (kib / 1048576).toFixed(1);
}

class RamApplet extends Applet.TextApplet {
    constructor(orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);
        this._update();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, INTERVAL_SECONDS, () => {
            this._update();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _update() {
        const kib = readMeminfo();
        if (!kib.MemTotal) {
            this.set_applet_label("RAM ?");
            return;
        }
        const used = kib.MemTotal - kib.MemAvailable;
        const swapUsed = kib.SwapTotal - kib.SwapFree;
        const percent = Math.round(100 * used / kib.MemTotal);

        this.set_applet_label(`RAM ${percent}%`);
        this._applet_label.set_style(percent >= CRITICAL_PERCENT ? `color: ${RED};` : "");
        this.set_applet_tooltip(`Memory: ${gib(used)} / ${gib(kib.MemTotal)} GiB\n`
            + `Swap: ${gib(swapUsed)} / ${gib(kib.SwapTotal)} GiB`);
    }

    on_applet_clicked() {
        Util.spawnCommandLine("gnome-system-monitor --show-resources-tab");
    }

    on_applet_removed_from_panel() {
        if (this._timer) {
            GLib.source_remove(this._timer);
            this._timer = 0;
        }
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new RamApplet(orientation, panelHeight, instanceId);
}
