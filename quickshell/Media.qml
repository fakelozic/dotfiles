import QtQuick
import Quickshell.Services.Mpris

// What is playing in any MPRIS player (Firefox, Spotify, mpv, Telegram…).
// Click for the player panel, right-click to play or pause.
Module {
    id: root

    // playerctld mirrors another player, so it would show up twice.
    readonly property var players: Mpris.players.values.filter(player => !player.dbusName.includes("playerctld"))
    // The player picked in the panel, while it exists.
    property MprisPlayer pinned: null
    readonly property MprisPlayer player: pinned && players.includes(pinned) ? pinned
        : players.find(player => player.isPlaying) ?? players[0] ?? null

    readonly property string title: player ? [player.trackArtist, player.trackTitle].filter(part => part).join(" – ") : ""

    text: title === "" ? "" : (player.isPlaying ? "\u{f075a}  " : "\u{f03e4}  ") + (title.length > 40 ? title.slice(0, 39) + "…" : title)
    textColor: player && player.isPlaying ? Theme.fg : Theme.muted
    tooltip: panel.open || !player ? "" : player.identity

    onClicked: event => {
        if (event.button === Qt.RightButton || event.button === Qt.MiddleButton) {
            if (player && player.canTogglePlaying)
                player.togglePlaying();
        } else {
            panel.toggle();
        }
    }

    MediaPanel {
        id: panel
        source: root
        players: root.players
        player: root.player
        onPicked: player => root.pinned = player
    }
}
