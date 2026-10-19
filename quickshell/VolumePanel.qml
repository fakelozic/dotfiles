import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// Output device, output and microphone volume, and each playing application.
Panel {
    id: root

    boxWidth: 360

    readonly property var sinks: Sound.nodes("Audio/Sink")
    readonly property var streams: Sound.nodes("Stream/Output/Audio")

    PwObjectTracker {
        objects: root.open ? root.sinks.concat(root.streams) : []
    }

    Label {
        text: "Output"
        color: Theme.muted
    }

    Repeater {
        model: root.sinks

        delegate: Rectangle {
            id: device

            required property PwNode modelData
            readonly property bool current: modelData === Sound.sink

            width: parent.width
            height: 26
            color: mouse.containsMouse ? Theme.bg1 : "transparent"

            Label {
                x: 6
                width: parent.width - 12
                anchors.verticalCenter: parent.verticalCenter
                text: (device.current ? "\u{f043e}  " : "\u{f043d}  ") + (device.modelData.nickname || device.modelData.description)
                color: device.current ? Theme.yellow : Theme.fg
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Pipewire.preferredDefaultAudioSink = device.modelData
            }
        }
    }

    VolumeRow {
        icon: Sound.icon
        node: Sound.sink
    }

    VolumeRow {
        visible: Sound.source !== null
        icon: Sound.source && Sound.source.audio && Sound.source.audio.muted ? "\u{f036d}" : "\u{f036c}"
        node: Sound.source
    }

    Label {
        visible: root.streams.length > 0
        text: "Applications"
        color: Theme.muted
    }

    Repeater {
        model: root.streams

        delegate: VolumeRow {
            required property PwNode modelData

            node: modelData
            appIcon: modelData.properties["application.icon-name"] ?? ""
            name: modelData.properties["application.name"] || modelData.description || modelData.name
        }
    }

    Button {
        text: "\u{f062e}  Mixer"
        textColor: Theme.muted
        onClicked: {
            root.open = false;
            Quickshell.execDetached(["pavucontrol"]);
        }
    }

    // A mute button, a slider and the percentage; applications also get a name.
    component VolumeRow: Column {
        id: row

        property PwNode node
        property string icon: ""
        property string appIcon: ""
        property string name: ""
        readonly property bool ready: node !== null && node.audio !== null
        readonly property bool muted: ready && node.audio.muted

        width: parent.width
        spacing: 2

        Row {
            visible: row.name !== ""
            spacing: 6

            IconImage {
                visible: row.appIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: row.appIcon !== "" ? Quickshell.iconPath(row.appIcon, true) : ""
            }

            Label {
                width: Math.min(implicitWidth, row.width - 30)
                text: row.name
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Button {
                width: 30
                padding: 0
                text: row.name !== "" ? (row.muted ? "\u{f075f}" : "") : row.icon
                textColor: row.muted ? Theme.red : Theme.fg
                onClicked: if (row.ready) row.node.audio.muted = !row.node.audio.muted
            }

            Slider {
                width: parent.width - 30 - 48 - 16
                anchors.verticalCenter: parent.verticalCenter
                value: row.ready ? row.node.audio.volume : 0
                dimmed: row.muted
                onMoved: value => {
                    if (row.ready)
                        row.node.audio.volume = value;
                }
            }

            Label {
                width: 48
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: row.ready ? Math.round(row.node.audio.volume * 100) + "%" : ""
                color: row.muted ? Theme.muted : Theme.fg
            }
        }
    }
}
