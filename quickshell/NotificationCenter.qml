import QtQuick
import Quickshell

// Every notification not yet dismissed, newest first, with Do Not Disturb and
// Clear all.
Panel {
    id: root

    boxWidth: 420

    // Ages are redrawn every half minute.
    property real now: Date.now()

    Timer {
        interval: 30000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Item {
        width: parent.width
        height: 26

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            bold: true
            color: Theme.yellow
        }

        Row {
            anchors.right: parent.right
            spacing: 4

            Button {
                text: Notifs.dnd ? "\u{f009b}  Do Not Disturb" : "\u{f009c}  Do Not Disturb"
                highlighted: Notifs.dnd
                highlightColor: Theme.purple
                textColor: Theme.muted
                onClicked: Notifs.toggleDnd()
            }

            Button {
                text: "\u{f01b4}  Clear"
                textColor: Theme.muted
                visible: Notifs.list.length > 0
                onClicked: Notifs.clear()
            }
        }
    }

    Label {
        visible: Notifs.list.length === 0
        width: parent.width
        topPadding: 20
        bottomPadding: 20
        horizontalAlignment: Text.AlignHCenter
        text: "\u{f009c}  No notifications"
        color: Theme.muted
    }

    ListView {
        id: view

        visible: Notifs.list.length > 0
        width: parent.width
        height: Math.min(contentHeight, 560)
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: [...Notifs.list].reverse()
        }

        delegate: NotificationCard {
            required property var modelData

            width: view.width
            notification: modelData
            now: root.now
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 150
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
}
