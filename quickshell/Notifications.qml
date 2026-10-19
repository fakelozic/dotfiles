import QtQuick

// The notification count. Left-click opens the notification center,
// right-click toggles Do Not Disturb (purple while on).
Module {
    id: root

    readonly property int count: Notifs.list.length

    text: (Notifs.dnd ? "\u{f009b}" : count > 0 ? "\u{f009a}" : "\u{f009c}") + (count > 0 ? "  " + count : "")
    textColor: Notifs.dnd ? Theme.purple : count > 0 ? Theme.fg : Theme.muted
    tooltip: center.open ? "" : Notifs.dnd ? "Do Not Disturb" : ""

    onClicked: event => {
        if (event.button === Qt.RightButton)
            Notifs.toggleDnd();
        else
            center.toggle();
    }

    Connections {
        target: Notifs
        function onCenterRequested() { center.toggle(); }
    }

    NotificationCenter {
        id: center
        source: root
    }
}
