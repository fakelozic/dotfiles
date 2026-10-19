import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Lock, log out, suspend, reboot or shut down. Opens from the bar's power
// button or `qs ipc call power toggle`. Arrow keys or h/l move, Enter picks,
// the underlined letter picks directly, and Escape or a click outside closes.
PanelWindow {
    id: root

    property bool open: false
    property int selected: 0

    readonly property var actions: [
        { key: "k", label: "Lock", icon: "\u{f033e}", command: ["loginctl", "lock-session"] },
        { key: "o", label: "Log out", icon: "\u{f0343}", command: ["swaymsg", "exit"] },
        { key: "s", label: "Suspend", icon: "\u{f04b2}", command: ["systemctl", "suspend"] },
        { key: "r", label: "Reboot", icon: "\u{f0709}", command: ["systemctl", "reboot"] },
        { key: "d", label: "Shut down", icon: "\u{f0425}", command: ["systemctl", "poweroff"] }
    ]

    function toggle() {
        selected = 0;
        open = !open;
    }

    // Opens with one action selected, so the launcher's Reboot and the like
    // still ask before acting.
    function choose(key) {
        selected = Math.max(0, actions.findIndex(action => action.key === key));
        open = true;
    }

    function run(index) {
        open = false;
        Quickshell.execDetached(actions[index].command);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-power"
    color: "transparent"
    visible: open || backdrop.opacity > 0

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle();
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.bg
        opacity: root.open ? 0.85 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 16
        opacity: backdrop.opacity / 0.85
        scale: 0.96 + 0.04 * opacity
        focus: root.open

        Keys.onPressed: event => {
            const key = event.text.toLowerCase();
            const index = root.actions.findIndex(action => action.key === key);
            if (event.key === Qt.Key_Escape)
                root.open = false;
            else if (event.key === Qt.Key_Left || key === "h")
                root.selected = (root.selected + root.actions.length - 1) % root.actions.length;
            else if (event.key === Qt.Key_Right || key === "l" || event.key === Qt.Key_Tab)
                root.selected = (root.selected + 1) % root.actions.length;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.run(root.selected);
            else if (index >= 0)
                root.run(index);
            else
                return;
            event.accepted = true;
        }

        Repeater {
            model: root.actions

            delegate: Rectangle {
                id: tile

                required property var modelData
                required property int index
                readonly property bool current: index === root.selected

                width: 140
                height: 140
                color: current ? Theme.yellow : Theme.bg0
                border.width: 1
                border.color: current ? Theme.yellow : Theme.bg2

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.icon
                        pixelSize: 40
                        color: tile.current ? Theme.bg : Theme.fg
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.StyledText
                        // Underline the letter that picks this action.
                        text: {
                            const label = tile.modelData.label;
                            const at = label.toLowerCase().indexOf(tile.modelData.key);
                            return label.slice(0, at) + "<u>" + label[at] + "</u>" + label.slice(at + 1);
                        }
                        color: tile.current ? Theme.bg : Theme.fg
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = tile.index
                    onClicked: root.run(tile.index)
                }
            }
        }
    }
}
