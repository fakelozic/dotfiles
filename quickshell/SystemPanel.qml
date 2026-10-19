import QtQuick
import Quickshell
import Quickshell.Io

// CPU per core, memory and swap, temperature, load and the busiest processes.
Panel {
    id: root

    property var facts: ({ temp: "", uptime: 0, load: [], procs: [] })

    boxWidth: 360

    onOpenChanged: SysStats.fast = open

    function gib(kib) {
        return (kib / 1048576).toFixed(1);
    }

    function since(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor(seconds % 86400 / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        return (days > 0 ? days + "d " : "") + hours + "h " + minutes + "m";
    }

    Process {
        id: probe
        command: ["sh", Quickshell.shellPath("system.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const facts = { temp: "", uptime: 0, load: [], procs: [] };
                for (const line of text.trim().split("\n")) {
                    const [kind, ...values] = line.split("\t");
                    if (kind === "temp")
                        facts.temp = values[0];
                    else if (kind === "uptime")
                        facts.uptime = Number(values[0]);
                    else if (kind === "load")
                        facts.load = values;
                    else if (kind === "proc")
                        facts.procs.push({ cpu: values[0], mem: values[1], name: values[2] });
                }
                root.facts = facts;
            }
        }
    }

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Item {
        width: parent.width
        height: 20

        Label {
            text: "  CPU  " + (SysStats.cpu[0] ?? 0) + "%"
            bold: true
            color: Theme.yellow
        }

        Label {
            anchors.right: parent.right
            text: root.facts.temp !== "" ? "\u{f050f} " + root.facts.temp + "°C" : ""
            color: Number(root.facts.temp) >= 80 ? Theme.red : Theme.muted
        }
    }

    // One bar per core.
    Row {
        id: cores

        readonly property var usage: SysStats.cpu.slice(1)

        width: parent.width
        height: 36
        spacing: 3

        Repeater {
            model: cores.usage.length

            delegate: Rectangle {
                required property int index

                width: (cores.width - cores.spacing * (cores.usage.length - 1)) / cores.usage.length
                height: cores.height
                color: Theme.bg1

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * (cores.usage[parent.index] ?? 0) / 100
                    color: (cores.usage[parent.index] ?? 0) >= 90 ? Theme.red : Theme.yellow

                    Behavior on height {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
            }
        }
    }

    Meter {
        label: "  Memory"
        used: SysStats.memUsed
        total: SysStats.memTotal
        critical: SysStats.memPercent >= 81
    }

    Meter {
        visible: SysStats.swapTotal > 0
        label: "\u{f04e6}  Swap"
        used: SysStats.swapUsed
        total: SysStats.swapTotal
    }

    Label {
        text: "Load " + root.facts.load.join("  ") + "    Up " + root.since(root.facts.uptime)
        color: Theme.muted
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: root.facts.procs

            delegate: Item {
                required property var modelData

                width: parent.width
                height: 20

                Label {
                    width: parent.width - 130
                    text: parent.modelData.name
                }

                Label {
                    x: parent.width - 130
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: parent.modelData.cpu + "%"
                    color: Theme.yellow
                }

                Label {
                    x: parent.width - 60
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: parent.modelData.mem + "%"
                    color: Theme.muted
                }
            }
        }
    }

    Button {
        text: "\u{f062e}  btop"
        textColor: Theme.muted
        onClicked: {
            root.open = false;
            Quickshell.execDetached(["alacritty", "-e", "btop"]);
        }
    }

    // A labelled bar with "used / total GiB".
    component Meter: Column {
        id: meter

        property string label
        property real used
        property real total
        property bool critical: false

        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 20

            Label {
                text: meter.label
            }

            Label {
                anchors.right: parent.right
                text: root.gib(meter.used) + " / " + root.gib(meter.total) + " GiB"
                color: meter.critical ? Theme.red : Theme.muted
            }
        }

        Rectangle {
            width: parent.width
            height: 6
            color: Theme.bg1

            Rectangle {
                width: parent.width * (meter.total > 0 ? meter.used / meter.total : 0)
                height: parent.height
                color: meter.critical ? Theme.red : Theme.aqua

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
        }
    }
}
