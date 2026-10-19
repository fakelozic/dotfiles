import QtQuick

// Key hints for the bottom of a card, such as "Enter open  Esc close". Each
// entry is [key, what it does].
Row {
    property var hints: []

    spacing: 16

    Repeater {
        model: parent.hints

        delegate: Row {
            required property var modelData

            spacing: 6

            Label {
                text: modelData[0]
                pixelSize: 13
                color: Theme.fg
            }

            Label {
                text: modelData[1]
                pixelSize: 13
                color: Theme.muted
                font.weight: Font.Normal
            }
        }
    }
}
