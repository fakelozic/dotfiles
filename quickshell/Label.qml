import QtQuick

// Text in the bar font and colors. pixelSize and bold adjust it.
Text {
    property int pixelSize: Theme.font.pixelSize
    property bool bold: false

    color: Theme.fg
    font.family: Theme.font.family
    font.pixelSize: pixelSize
    font.weight: bold ? Font.ExtraBold : Theme.font.weight
    elide: Text.ElideRight
}
