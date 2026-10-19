import QtQuick
import Quickshell

// What each screen shows while locked: the wallpaper, the time and a password
// box. Typing goes to whichever screen has the keyboard; all share one password.
Item {
    id: root

    required property var lock

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/walls/burning-earth.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.6
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.lock.submit();
            } else if (event.key === Qt.Key_Escape) {
                root.lock.password = "";
            } else if (event.key === Qt.Key_Backspace) {
                root.lock.password = event.modifiers & Qt.ControlModifier ? "" : root.lock.password.slice(0, -1);
            } else if (event.text !== "" && event.text.charCodeAt(0) >= 32 && !root.lock.busy) {
                root.lock.password += event.text;
                root.lock.message = "";
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            pixelSize: 96
            bold: true
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            pixelSize: 20
            color: Theme.yellow
        }

        Item {
            width: 1
            height: 28
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\u{f0009}  " + Quickshell.env("USER")
            color: Theme.muted
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 44
            color: Theme.bg
            border.width: 2
            border.color: root.lock.busy ? Theme.aqua : root.lock.message !== "" ? Theme.red : Theme.yellow

            transform: Translate {
                id: shake
            }

            Label {
                anchors.centerIn: parent
                visible: root.lock.password === ""
                text: root.lock.busy ? "Checking…" : "\u{f033e}  Password"
                color: Theme.muted
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: Math.min(root.lock.password.length, 24)

                    delegate: Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.fg
                    }
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 20
            text: root.lock.message
            color: Theme.red
        }
    }

    Connections {
        target: root.lock
        function onFailed() { wobble.restart(); }
    }

    SequentialAnimation {
        id: wobble
        loops: 2
        NumberAnimation { target: shake; property: "x"; to: -12; duration: 40 }
        NumberAnimation { target: shake; property: "x"; to: 12; duration: 80 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 40 }
    }
}
