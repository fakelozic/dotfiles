import QtQuick
import Quickshell

// A tooltip that opens above its target after the pointer rests on it.
// The text is styled text; long lines wrap at 480 px.
PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool hovered: false

    property bool open: false

    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -4
    visible: open && text !== ""
    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 12
    color: "transparent"

    onHoveredChanged: if (!hovered) open = false

    Timer {
        interval: 500
        running: root.hovered && !root.open
        onTriggered: root.open = true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2

        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 480)
            wrapMode: Text.Wrap
            text: root.text
            textFormat: Text.StyledText
            color: Theme.fg
            font: Theme.font
        }
    }
}
