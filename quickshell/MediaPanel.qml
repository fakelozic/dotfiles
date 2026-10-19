import QtQuick
import Quickshell.Services.Mpris

// Cover art, track, a seek bar and controls. With several players, tabs pick one.
Panel {
    id: root

    required property var players
    required property MprisPlayer player

    signal picked(MprisPlayer player)

    boxWidth: 380

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        const rest = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + rest : m + ":" + rest;
    }

    // MPRIS does not announce position changes during playback.
    Timer {
        interval: 1000
        running: root.open && root.player !== null && root.player.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Flow {
        visible: root.players.length > 1
        width: parent.width
        spacing: 4

        Repeater {
            model: root.players

            delegate: Button {
                required property MprisPlayer modelData

                text: modelData.identity
                highlighted: modelData === root.player
                onClicked: root.picked(modelData)
            }
        }
    }

    Label {
        visible: root.player === null
        text: "Nothing is playing"
        color: Theme.muted
    }

    Row {
        visible: root.player !== null
        width: parent.width
        spacing: 12

        Rectangle {
            width: 96
            height: 96
            color: Theme.bg1

            Label {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "\u{f075a}"
                pixelSize: 36
                color: Theme.muted
            }

            Image {
                id: art
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 192
                sourceSize.height: 192
            }
        }

        Column {
            width: parent.width - 96 - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Label {
                width: parent.width
                text: root.player ? root.player.trackTitle || root.player.identity : ""
                bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Label {
                width: parent.width
                text: root.player ? root.player.trackArtist : ""
                color: Theme.yellow
            }

            Label {
                width: parent.width
                text: root.player ? root.player.trackAlbum : ""
                color: Theme.muted
            }
        }
    }

    Column {
        visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
        width: parent.width
        spacing: 2

        Slider {
            width: parent.width
            value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
            onMoved: value => {
                if (root.player.canSeek)
                    root.player.position = value * root.player.length;
            }
        }

        Item {
            width: parent.width
            height: 18

            Label {
                text: root.player ? root.time(root.player.position) : ""
                color: Theme.muted
            }

            Label {
                anchors.right: parent.right
                text: root.player ? root.time(root.player.length) : ""
                color: Theme.muted
            }
        }
    }

    Row {
        visible: root.player !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16

        Button {
            text: "\u{f04ae}"
            textColor: root.player && root.player.canGoPrevious ? Theme.fg : Theme.bg2
            onClicked: if (root.player.canGoPrevious) root.player.previous()
        }

        Button {
            width: 44
            text: root.player && root.player.isPlaying ? "\u{f03e4}" : "\u{f040a}"
            highlighted: true
            onClicked: if (root.player.canTogglePlaying) root.player.togglePlaying()
        }

        Button {
            text: "\u{f04ad}"
            textColor: root.player && root.player.canGoNext ? Theme.fg : Theme.bg2
            onClicked: if (root.player.canGoNext) root.player.next()
        }
    }
}
