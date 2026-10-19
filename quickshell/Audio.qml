import QtQuick

// Default output volume. Click for the volume panel, right-click to mute,
// scroll to change it by 2%.
Module {
    id: root

    readonly property bool panelOpen: panel.open

    text: !Sound.ready ? "" : Sound.muted ? Sound.icon + "  muted" : Sound.icon + "  " + Sound.volume + "%"
    textColor: Sound.muted ? Theme.red : Theme.fg
    tooltip: panel.open ? "" : Sound.sink ? Sound.sink.description : ""

    onClicked: event => {
        if (event.button === Qt.RightButton)
            Sound.toggleMute();
        else
            panel.toggle();
    }
    onScrolled: event => {
        if (event.angleDelta.y !== 0)
            Sound.step(event.angleDelta.y > 0);
    }

    VolumePanel {
        id: panel
        source: root
    }
}
