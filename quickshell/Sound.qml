pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default output and input, shared by the bar, the volume panel and the OSD.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property bool muted: ready && sink.audio.muted
    readonly property int volume: ready ? Math.round(sink.audio.volume * 100) : 0
    readonly property var props: sink ? sink.properties : ({})
    readonly property bool bluetooth: props["device.api"] === "bluez5"
    readonly property bool headphones: ["headphone", "headset"].includes(props["device.form-factor"])

    readonly property string icon: muted ? "\u{f075f}"
        : bluetooth ? "\u{f00b0}"
        : headphones ? ""
        : ["", "", ""][Math.min(Math.floor(volume / 33), 2)]

    // Nodes by PipeWire media class, for the device and application lists.
    function nodes(mediaClass) {
        return Pipewire.nodes.values.filter(node => node.properties["media.class"] === mediaClass);
    }

    function setVolume(percent) {
        if (ready)
            sink.audio.volume = Math.max(0, percent) / 100;
    }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    // Scrolling up stops at 100% but never lowers a louder volume.
    function step(up) {
        setVolume(up ? Math.min(volume + 2, Math.max(volume, 100)) : volume - 2);
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
