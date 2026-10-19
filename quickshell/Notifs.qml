pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon. Every notification stays in the center until it is
// dismissed; new ones also pop up unless Do Not Disturb is on (critical ones
// still do). `qs ipc call notifications toggle|dnd|clear` drives it from Sway.
Singleton {
    id: root

    // Oldest first.
    readonly property var list: server.trackedNotifications.values
    // Notifications showing as popups, oldest first.
    property list<Notification> popups: []
    // When each notification id arrived, in ms since the epoch.
    property var arrived: ({})
    readonly property bool dnd: persist.dnd

    signal centerRequested()

    function toggleDnd() {
        persist.dnd = !persist.dnd;
    }

    function clear() {
        for (const notification of [...list])
            notification.dismiss();
    }

    // A popup that times out or is clicked away stays in the center, except
    // for transient ones, which are gone for good.
    function hidePopup(notification) {
        popups = popups.filter(popup => popup !== notification);
        if (notification.transient)
            notification.dismiss();
    }

    PersistentProperties {
        id: persist
        reloadableId: "notifications"
        property bool dnd: false
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true

        onNotification: notification => {
            // Fedora's volume keys announce the volume this way; the OSD shows it.
            if (notification.hints["x-canonical-private-synchronous"] === "volume")
                return;

            notification.tracked = true;
            root.arrived = Object.assign({}, root.arrived, { [notification.id]: Date.now() });
            notification.closed.connect(() => root.popups = root.popups.filter(popup => popup !== notification));

            if (!root.dnd || notification.urgency === NotificationUrgency.Critical)
                root.popups = root.popups.filter(popup => popup.id !== notification.id).concat([notification]);
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.centerRequested();
        }
        function dnd(): void {
            root.toggleDnd();
        }
        function clear(): void {
            root.clear();
        }
    }
}
