import QtQuick

// One block of text on the bar, hidden while its text is empty.
Rectangle {
    id: root

    property alias text: label.text
    property color textColor: Theme.fg
    property int leftPadding: 6
    property int rightPadding: 6
    property int minTextWidth: 0
    property string tooltip: ""
    readonly property alias hovered: mouse.containsMouse
    readonly property int textWidth: Math.max(label.implicitWidth, minTextWidth)

    signal clicked(var mouse)
    signal scrolled(var wheel)

    visible: text !== ""
    implicitWidth: textWidth + leftPadding + rightPadding
    height: parent ? parent.height : 0
    color: "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    Text {
        id: label
        x: root.leftPadding + Math.round((root.textWidth - implicitWidth) / 2)
        anchors.verticalCenter: parent.verticalCenter
        color: root.textColor
        font: Theme.font
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => root.clicked(event)
        onWheel: event => root.scrolled(event)
    }

    Tooltip {
        target: root
        text: root.tooltip
        hovered: root.hovered
    }
}
