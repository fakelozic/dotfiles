import QtQuick
import Quickshell
import Quickshell.Wayland

// A box that opens above the bar item it belongs to. It covers the screen
// with an invisible layer, so a click anywhere else or Escape closes it, and
// it takes the keyboard while open. Keybinds can open it too.
PanelWindow {
    id: root

    required property Item source
    property bool open: false
    property int boxWidth: 320
    default property alias content: column.data

    // Where the source item's center is, measured when the panel opens.
    property real sourceX: 0

    // A panel shared by several bar items opens above the one passed in.
    function toggle(from) {
        if (from && from !== source) {
            source = from;
            open = false;
        }
        if (!open) {
            const window = source.QsWindow.window;
            if (window)
                sourceX = window.mapFromItem(source, source.width / 2, 0).x;
        }
        open = !open;
    }

    screen: source.QsWindow.window ? source.QsWindow.window.screen : null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-panel"
    color: "transparent"
    visible: open || fade.running || box.opacity > 0

    MouseArea {
        anchors.fill: parent
        onClicked: root.open = false
    }

    Rectangle {
        id: box

        width: root.boxWidth
        height: column.implicitHeight + 24
        x: Math.max(8, Math.min(root.sourceX - width / 2, parent.width - width - 8))
        y: parent.height - 26 - 6 - height + (root.open ? 0 : 8)
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2
        opacity: root.open ? 1 : 0
        focus: root.open

        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: 120
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Keys.onEscapePressed: root.open = false

        // Clicks inside the box stay inside.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 10
        }
    }
}
