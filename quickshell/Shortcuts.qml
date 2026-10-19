import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import "Bindings.js" as Bindings

// Every Sway key binding in plain words, read from the running config and the
// config.d snippets it includes, so it always matches the real keys. Typing
// filters by key or description; Enter does what the selected shortcut does.
// Opens from the launcher ("Keyboard shortcuts") or by right-clicking the
// bar's menu button.
Picker {
    id: root

    property var bindings: []

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        show();
        read.running = true;
    }

    name: "shortcuts"
    size: 0.5
    preferredRowHeight: 40
    icon: "\u{f097b}"
    placeholder: "Search shortcuts, like “workspace” or “shift”"
    emptyText: "No matching shortcuts"
    hints: [["Enter", "do it now"], ["↑↓", "move"], ["Esc", "close"]]
    items: Bindings.filter(bindings, query)

    onActivated: binding => {
        open = false;
        I3.dispatch(binding.command);
    }

    IpcHandler {
        target: "shortcuts"

        function toggle(): void {
            root.toggle();
        }
    }

    // The main config, then each config.d file Sway includes: the user's copy
    // of a file name wins over /etc's, which wins over /usr/share's.
    Process {
        id: read
        command: ["sh", "-c", `
            cfg="\${XDG_CONFIG_HOME:-$HOME/.config}/sway"
            printf '#@file %s\\n' "$cfg/config"; cat "$cfg/config"
            for name in $(ls /usr/share/sway/config.d /etc/sway/config.d "$cfg/config.d" 2>/dev/null | grep '[.]conf$' | sort -u); do
                for dir in "$cfg/config.d" /etc/sway/config.d /usr/share/sway/config.d; do
                    if [ -f "$dir/$name" ]; then printf '\\n#@file %s\\n' "$dir/$name"; cat "$dir/$name"; break; fi
                done
            done`]
        stdout: StdioCollector {
            onStreamFinished: root.bindings = Bindings.parse(text)
        }
    }

    delegate: PickerRow {
        id: row

        picker: root

        Row {
            id: keys
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(row.width * 0.36)
            spacing: 4

            Repeater {
                model: row.modelData.keys

                delegate: Rectangle {
                    required property string modelData
                    readonly property bool word: modelData === "then"

                    width: word ? cap.implicitWidth : Math.max(24, cap.implicitWidth + 12)
                    height: 24
                    color: word ? "transparent" : row.current ? Theme.bg : Theme.bg1

                    Label {
                        id: cap
                        anchors.centerIn: parent
                        text: parent.modelData
                        pixelSize: 13
                        color: parent.word ? row.dim : row.current ? Theme.yellow : Theme.fg
                        font.weight: parent.word ? Font.Normal : Theme.font.weight
                    }
                }
            }
        }

        Label {
            anchors.left: keys.right
            anchors.leftMargin: 12
            anchors.right: section.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.description
            pixelSize: 15
            color: row.fg
        }

        Label {
            id: section
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.section
            pixelSize: 13
            color: row.dim
            font.weight: Font.Normal
        }
    }
}
