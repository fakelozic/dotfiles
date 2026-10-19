import QtQuick
import Quickshell
import Quickshell.Wayland

// Shows the output volume above the bar for a moment whenever it changes,
// whether from the media keys, the bar or another program.
PanelWindow {
    id: root

    property bool shown: false
    // Set while the volume panel is open, which shows the volume already.
    property bool suppressed: false

    anchors.bottom: true
    margins.bottom: 26 + 60
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    implicitWidth: 300
    implicitHeight: 52
    color: "transparent"
    mask: Region {}
    visible: shown || box.opacity > 0

    function show() {
        if (suppressed || !ready.done)
            return;
        shown = true;
        hide.restart();
    }

    Connections {
        target: Sound
        function onVolumeChanged() { root.show(); }
        function onMutedChanged() { root.show(); }
        function onSinkChanged() { root.show(); }
    }

    // PipeWire reports the starting volume as a change; ignore it.
    Timer {
        id: ready
        property bool done: false
        interval: 1000
        running: true
        onTriggered: done = true
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    Rectangle {
        id: box
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2
        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 12

            Label {
                width: 22
                anchors.verticalCenter: parent.verticalCenter
                text: Sound.icon
                pixelSize: 18
                color: Sound.muted ? Theme.red : Theme.fg
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                height: 6
                color: Theme.bg1

                Rectangle {
                    width: parent.width * Math.min(1, Sound.volume / 100)
                    height: parent.height
                    color: Sound.muted ? Theme.muted : Theme.yellow

                    Behavior on width {
                        NumberAnimation {
                            duration: 80
                        }
                    }
                }
            }

            Label {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Sound.muted ? "muted" : Sound.volume + "%"
                color: Sound.muted ? Theme.muted : Theme.fg
            }
        }
    }
}
