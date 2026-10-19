import QtQuick
import Quickshell
import Quickshell.Io

// The interface carrying the default route: Wi-Fi signal, wired or offline.
// Click for the network panel.
Module {
    id: root

    // kind, signal, essid, ifname, ipaddr
    property var info: ["disconnected", "", "", "", ""]

    text: info[0] === "wifi" ? "  " + info[1] + "%"
        : info[0] === "ethernet" ? "\u{f0200}  wired"
        : "\u{f05aa}  offline"
    textColor: info[0] === "disconnected" ? Theme.red : Theme.fg
    tooltip: panel.open ? ""
           : info[0] === "wifi" ? info[2] + "<br>" + info[4]
           : info[0] === "ethernet" ? info[3] + "<br>" + info[4]
           : "Disconnected"

    onClicked: panel.toggle()

    Process {
        id: probe
        command: ["sh", Quickshell.shellPath("network.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split("\t");
                root.info = fields[0] === "wifi" || fields[0] === "ethernet" ? fields : ["disconnected", "", "", "", ""];
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    NetworkPanel {
        id: panel
        source: root
        info: root.info
    }
}
