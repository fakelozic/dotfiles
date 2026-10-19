pragma Singleton

import QtQuick
import Quickshell

// Gruvbox colors and the bar font, shared by every module.
Singleton {
    readonly property color bg: "#1d2021"
    readonly property color bg0: "#282828"
    readonly property color bg1: "#3c3836"
    readonly property color bg2: "#504945"
    readonly property color fg: "#ebdbb2"
    readonly property color muted: "#a89984"
    readonly property color red: "#fb4934"
    readonly property color green: "#b8bb26"
    readonly property color yellow: "#fabd2f"
    readonly property color blue: "#83a598"
    readonly property color purple: "#d3869b"
    readonly property color aqua: "#8ec07c"
    readonly property color orange: "#fe8019"

    // Animation lengths in ms, kept short so nothing waits on them.
    readonly property int fast: 100
    readonly property int normal: 160

    readonly property font font: Qt.font({
        family: "JetBrainsMono Nerd Font",
        pixelSize: 14,
        weight: Font.DemiBold
    })
}
