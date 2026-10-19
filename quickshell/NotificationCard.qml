import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// One notification: icon, app and age, summary, body and action buttons.
// Clicking it runs its default action. As a popup it hides after its timeout
// (paused while hovered); in the center the × dismisses it.
Rectangle {
    id: root

    required property Notification notification
    property bool popup: false
    property real now: Date.now()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notification.actions.find(action => action.identifier === "default") ?? null
    readonly property var buttons: notification.actions.filter(action => action.identifier !== "default")
    readonly property string icon: {
        const n = notification;
        if (n.image !== "")
            return n.image;
        const name = n.appIcon !== "" ? n.appIcon : (DesktopEntries.byId(n.desktopEntry)?.icon ?? "");
        if (name === "")
            return "";
        return name.startsWith("/") || name.includes("://") ? name : Quickshell.iconPath(name, true);
    }
    // Apps give the timeout in ms, or -1/0 for the default: 5 s for low
    // urgency, 10 s for normal and no timeout for critical.
    readonly property int timeout: notification.expireTimeout > 0 ? notification.expireTimeout
        : critical ? 0
        : notification.urgency === NotificationUrgency.Low ? 5000 : 10000

    function age() {
        const seconds = (now - (Notifs.arrived[notification.id] ?? now)) / 1000;
        if (seconds < 60)
            return "now";
        if (seconds < 3600)
            return Math.floor(seconds / 60) + "m";
        if (seconds < 86400)
            return Math.floor(seconds / 3600) + "h";
        return Math.floor(seconds / 86400) + "d";
    }

    function close() {
        if (popup)
            Notifs.hidePopup(notification);
        else
            notification.dismiss();
    }

    width: parent ? parent.width : 400
    height: content.implicitHeight + 20
    color: mouse.containsMouse ? Theme.bg1 : Theme.bg0
    border.width: 1
    border.color: critical ? Theme.red : Theme.bg2

    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }

    Timer {
        interval: root.timeout
        running: root.popup && root.timeout > 0 && !mouse.containsMouse
        onTriggered: Notifs.hidePopup(root.notification)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: event => {
            if (event.button === Qt.MiddleButton)
                root.notification.dismiss();
            else if (root.defaultAction)
                root.defaultAction.invoke();
            else if (root.popup)
                root.close();
        }
    }

    Row {
        id: content
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 10

        Item {
            width: 40
            height: 40

            IconImage {
                anchors.fill: parent
                visible: root.icon !== "" && status === Image.Ready
                source: root.icon
                asynchronous: true
            }

            Label {
                anchors.centerIn: parent
                visible: root.icon === ""
                text: "\u{f009a}"
                pixelSize: 24
                color: root.critical ? Theme.red : Theme.muted
            }
        }

        Column {
            width: parent.width - 50
            spacing: 3

            Item {
                width: parent.width
                height: 18

                Label {
                    width: parent.width - 60
                    text: root.notification.appName || "Notification"
                    color: Theme.muted
                }

                Label {
                    anchors.right: closeButton.left
                    anchors.rightMargin: 6
                    text: root.age()
                    color: Theme.muted
                }

                Label {
                    id: closeButton
                    anchors.right: parent.right
                    text: "\u{f0156}"
                    color: closeMouse.containsMouse ? Theme.red : Theme.muted

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }

            Label {
                width: parent.width
                text: root.notification.summary
                bold: true
                color: root.critical ? Theme.red : Theme.fg
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Label {
                visible: text !== ""
                width: parent.width
                text: root.notification.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 8
                linkColor: Theme.blue
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                visible: root.buttons.length > 0
                width: parent.width
                spacing: 6
                topPadding: 4

                Repeater {
                    model: root.buttons

                    delegate: Button {
                        required property NotificationAction modelData

                        text: modelData.text
                        baseColor: Theme.bg1
                        hoverColor: Theme.bg2
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
