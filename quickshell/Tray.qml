import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Status notifier icons. Left-click activates, right-click opens the menu.
Row {
    id: root

    visible: SystemTray.items.values.length > 0
    leftPadding: 6
    rightPadding: 6
    spacing: 8

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property SystemTrayItem modelData

            width: 16
            height: root.height

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: entry.modelData.icon
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: event => {
                    if (event.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else if (event.button === Qt.RightButton || entry.modelData.onlyMenu)
                        menu.toggle();
                    else
                        entry.modelData.activate();
                }
                onWheel: event => entry.modelData.scroll(event.angleDelta.y, false)
            }

            TrayMenu {
                id: menu
                target: entry
                menu: entry.modelData.menu
            }

            Tooltip {
                target: entry
                // Apps send plain text with newlines.
                text: [entry.modelData.tooltipTitle || entry.modelData.title, entry.modelData.tooltipDescription]
                    .filter(line => line)
                    .join("\n")
                    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                    .replace(/\n/g, "<br>")
                hovered: mouse.containsMouse && !menu.visible
            }
        }
    }
}
