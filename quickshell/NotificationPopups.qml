import QtQuick
import Quickshell
import Quickshell.Wayland

// New notifications in the top-right corner, newest on top, at most five.
// Clicks between them reach the windows underneath.
PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }
    margins {
        top: 8
        right: 8
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"
    visible: Notifs.popups.length > 0
    mask: Region {
        item: column
    }

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: ScriptModel {
                values: Notifs.popups.slice(-5).reverse()
            }

            delegate: NotificationCard {
                id: card

                required property var modelData

                notification: modelData
                popup: true
                opacity: 0
                transform: Translate {
                    id: slide
                    x: 40
                }

                Component.onCompleted: appear.start()

                ParallelAnimation {
                    id: appear
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 1
                        duration: 150
                    }
                    NumberAnimation {
                        target: slide
                        property: "x"
                        to: 0
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
