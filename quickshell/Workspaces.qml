import QtQuick
import Quickshell
import Quickshell.I3

// Workspaces from every output, in number order. Click one to switch to it.
Row {
    id: root

    Repeater {
        model: ScriptModel {
            values: [...I3.workspaces.values].sort((a, b) => a.number - b.number || a.name.localeCompare(b.name))
        }

        delegate: Item {
            id: button

            required property I3Workspace modelData

            width: box.width + 2
            height: root.height

            // At least 32 px wide, covering the bar's top border and stopping
            // 1 px above the bottom.
            Rectangle {
                id: box
                x: 1
                y: -1
                width: Math.max(32, label.implicitWidth + 12)
                height: parent.height
                color: button.modelData.focused ? Theme.yellow
                     : button.modelData.urgent ? Theme.red
                     : mouse.containsMouse ? Theme.bg1
                     : "transparent"

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: button.modelData.name
                    color: button.modelData.focused || button.modelData.urgent ? Theme.bg
                         : mouse.containsMouse ? Theme.fg
                         : Theme.muted
                    font: Theme.font
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: button.modelData.activate()
            }
        }
    }
}
