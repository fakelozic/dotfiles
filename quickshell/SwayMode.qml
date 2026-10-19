import QtQuick
import Quickshell.I3

// The active Sway binding mode; hidden in the default mode.
Module {
    id: root

    property string mode: "default"

    text: mode === "default" ? "" : "\u{f030c}  " + mode
    textColor: Theme.bg
    color: Theme.orange
    leftPadding: 7
    rightPadding: 7

    I3IpcListener {
        subscriptions: ["mode"]
        // The first event is the reply to the subscription itself.
        onIpcEvent: event => {
            if (event.type === "mode")
                root.mode = JSON.parse(event.data).change;
        }
    }
}
