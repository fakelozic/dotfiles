import QtQuick
import Quickshell.I3
import Quickshell.Io

// Title of the window focused on the bar's output, even while focus is on
// another output. Firefox titles get its icon instead of the browser name.
Module {
    id: root

    required property string output
    property string title: ""

    readonly property string shown: title.replace(/^(.*) — Mozilla Firefox$/, "  $1")

    text: shown.length > 48 ? shown.slice(0, 47) + "…" : shown
    textColor: Theme.muted

    // Follows the output's focus chain down to the window it last focused.
    Process {
        id: tree
        property bool again: false
        command: ["sh", "-c", `swaymsg -t get_tree | jq -r --arg out "$1" '
            def leaf: (.focus[0] // null) as $f
                | if $f == null then . else first((.nodes + (.floating_nodes // []))[] | select(.id == $f)) | leaf end;
            first(.nodes[] | select(.name == $out)) | leaf
                | if .type == "con" or .type == "floating_con" then .name // "" else "" end'`,
            "sh", root.output]
        stdout: StdioCollector {
            onStreamFinished: root.title = text.trim()
        }
        onExited: if (again) {
            again = false;
            running = true;
        }
    }

    function refresh() {
        if (tree.running)
            tree.again = true;
        else
            tree.running = true;
    }

    I3IpcListener {
        subscriptions: ["window", "workspace"]
        onIpcEvent: root.refresh()
    }

    Component.onCompleted: refresh()
}
