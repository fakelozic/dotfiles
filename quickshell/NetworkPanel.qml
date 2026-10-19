import QtQuick
import Quickshell
import Quickshell.Io

// Details of the active connection and its current download and upload rates.
Panel {
    id: root

    // kind, signal, essid, ifname, ipaddr; from Network.qml
    required property var info
    readonly property string device: info[3]

    // NetworkManager's view of the device, as "KEY: value" pairs.
    property var details: ({})
    property real down: 0
    property real up: 0
    property var last: null

    boxWidth: 340

    function rate(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MB/s";
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(0) + " KB/s";
        return Math.round(bytes) + " B/s";
    }

    function field(key) {
        return details[key] ?? "";
    }

    onOpenChanged: {
        if (open && device !== "") {
            last = null;
            show.running = true;
        }
    }

    Process {
        id: show
        command: ["nmcli", "-t", "-f", "GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show", root.device]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {};
                for (const line of text.trim().split("\n")) {
                    const split = line.indexOf(":");
                    const key = line.slice(0, split).replace(/\[\d+\]$/, "");
                    const value = line.slice(split + 1).replace(/\\:/g, ":");
                    if (value !== "")
                        result[key] = result[key] ? result[key] + ", " + value : value;
                }
                root.details = result;
            }
        }
    }

    FileView {
        id: rx
        path: root.device !== "" ? `/sys/class/net/${root.device}/statistics/rx_bytes` : ""
    }

    FileView {
        id: tx
        path: root.device !== "" ? `/sys/class/net/${root.device}/statistics/tx_bytes` : ""
    }

    FileView {
        id: speed
        path: root.device !== "" ? `/sys/class/net/${root.device}/speed` : ""
    }

    Timer {
        interval: 1000
        running: root.open && root.device !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            rx.reload();
            tx.reload();
            const now = { time: Date.now(), rx: Number(rx.text()), tx: Number(tx.text()) };
            if (root.last) {
                const seconds = (now.time - root.last.time) / 1000;
                root.down = (now.rx - root.last.rx) / seconds;
                root.up = (now.tx - root.last.tx) / seconds;
            }
            root.last = now;
        }
    }

    Label {
        width: parent.width
        text: root.info[0] === "wifi" ? "  " + root.info[2] + "  ·  " + root.info[1] + "%"
            : root.info[0] === "ethernet" ? "\u{f0200}  " + (root.field("GENERAL.CONNECTION") || "Wired")
            : "\u{f05aa}  Offline"
        bold: true
        color: root.info[0] === "disconnected" ? Theme.red : Theme.yellow
    }

    Grid {
        visible: root.device !== ""
        columns: 2
        columnSpacing: 12
        rowSpacing: 4

        Label { text: "Device"; color: Theme.muted }
        Label {
            width: 240
            text: root.device + (Number(speed.text()) > 0 ? "  ·  " + Number(speed.text()) + " Mb/s" : "")
        }
        Label { text: "IPv4"; color: Theme.muted }
        Label { width: 240; text: root.field("IP4.ADDRESS") || root.info[4] }
        Label { text: "Gateway"; color: Theme.muted; visible: root.field("IP4.GATEWAY") !== "" }
        Label { width: 240; text: root.field("IP4.GATEWAY"); visible: text !== "" }
        Label { text: "DNS"; color: Theme.muted; visible: root.field("IP4.DNS") !== "" }
        Label { width: 240; text: root.field("IP4.DNS"); visible: text !== ""; wrapMode: Text.Wrap }
        Label { text: "IPv6"; color: Theme.muted; visible: root.field("IP6.ADDRESS") !== "" }
        Label { width: 240; text: root.field("IP6.ADDRESS").split(", ")[0]; visible: text !== "" }
    }

    Row {
        visible: root.device !== ""
        spacing: 24

        Label { text: "\u{f01da}  " + root.rate(root.down); color: Theme.aqua }
        Label { text: "\u{f0552}  " + root.rate(root.up); color: Theme.blue }
    }

    Button {
        text: "\u{f062e}  Connections"
        textColor: Theme.muted
        onClicked: {
            root.open = false;
            Quickshell.execDetached(["nm-connection-editor"]);
        }
    }
}
