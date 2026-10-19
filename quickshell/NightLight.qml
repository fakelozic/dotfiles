import QtQuick
import Quickshell
import Quickshell.Io

// Whether wlsunset is running. Click to start or stop it.
Module {
    id: root

    property bool on: false

    text: on ? "\u{f0594}" : "\u{f0599}"
    textColor: on ? Theme.orange : Theme.muted
    tooltip: on ? "Night light on (06:30–18:30 day)" : "Night light off"

    onClicked: {
        Quickshell.execDetached(["sh", "-c", '"$HOME/.local/bin/nightlight" toggle']);
        recheck.restart();
    }

    Process {
        id: status
        command: ["sh", "-c", '"$HOME/.local/bin/nightlight" status']
        onExited: code => root.on = code === 0
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: status.running = true
    }

    // Gives the toggle time to start or stop wlsunset.
    Timer {
        id: recheck
        interval: 300
        onTriggered: status.running = true
    }
}
