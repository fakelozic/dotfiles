import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// The password prompt apps get when they ask for administrator rights, such
// as Boxes, Disks or pkexec. It shows what is being asked for and which polkit
// action that is. Enter authenticates and Escape cancels; a wrong password
// shakes the field and clears it. Fedora's lxqt agent is switched off in
// sway/config.d so this is the only agent.
Overlay {
    id: root

    readonly property AuthFlow flow: agent.flow
    property bool busy: false
    property bool wrong: false

    function submit() {
        if (flow === null || !flow.isResponseRequired)
            return;
        busy = true;
        wrong = false;
        flow.submit(password.text);
        password.text = "";
    }

    function cancel() {
        if (flow !== null)
            flow.cancelAuthenticationRequest();
    }

    name: "polkit"
    open: agent.isActive
    dismissable: false
    cardWidth: 460
    cardHeight: column.implicitHeight + 48

    onOpenChanged: {
        busy = false;
        wrong = false;
        password.text = "";
    }

    PolkitAgent {
        id: agent
        path: "/org/quickshell/PolkitAgent"
    }

    Connections {
        target: root.flow

        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired) {
                root.busy = false;
                password.forceActiveFocus();
            }
        }

        function onAuthenticationFailed() {
            root.busy = false;
            root.wrong = true;
            shake.restart();
        }
    }

    Column {
        id: column

        x: 24
        y: 24
        width: parent.width - 48
        spacing: 12

        Row {
            spacing: 12

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f099d}"
                pixelSize: 28
                color: Theme.yellow
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Administrator password needed"
                pixelSize: 18
                bold: true
            }
        }

        Label {
            width: parent.width
            text: root.flow?.message ?? ""
            pixelSize: 15
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            font.weight: Font.Normal
        }

        Label {
            width: parent.width
            text: root.flow?.actionId ?? ""
            pixelSize: 13
            color: Theme.muted
            font.weight: Font.Normal
        }

        Rectangle {
            id: field

            width: parent.width
            height: 44
            color: Theme.bg
            border.width: 2
            border.color: root.busy ? Theme.aqua : root.wrong ? Theme.red : Theme.yellow

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }

            transform: Translate {
                id: offset
            }

            TextInput {
                id: password

                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                passwordCharacter: "●"
                color: Theme.fg
                font.family: Theme.font.family
                font.pixelSize: 16
                enabled: !root.busy
                focus: root.open
                clip: true

                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
                Keys.onEscapePressed: root.cancel()

                Label {
                    visible: password.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.busy ? "Checking…" : (root.flow?.inputPrompt ?? "Password").replace(/:\s*$/, "")
                    color: Theme.muted
                    font.weight: Font.Normal
                }
            }
        }

        Label {
            visible: text !== ""
            width: parent.width
            text: root.wrong ? "That password did not work. Try again." : root.flow?.supplementaryMessage ?? ""
            pixelSize: 14
            wrapMode: Text.Wrap
            color: root.wrong || root.flow?.supplementaryIsError ? Theme.red : Theme.muted
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            Button {
                text: "Cancel"
                textColor: Theme.muted
                onClicked: root.cancel()
            }

            Button {
                text: "\u{f0bc4}  Authenticate"
                highlighted: true
                onClicked: root.submit()
            }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: offset; property: "x"; to: -10; duration: 40 }
        NumberAnimation { target: offset; property: "x"; to: 10; duration: 70 }
        NumberAnimation { target: offset; property: "x"; to: 0; duration: 40 }
    }
}
