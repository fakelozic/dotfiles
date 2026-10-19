import QtQuick

// A flat text button for panels. Highlighted ones use an accent, yellow by default.
Rectangle {
    id: root

    property alias text: label.text
    property color textColor: Theme.fg
    property bool highlighted: false
    property color highlightColor: Theme.yellow
    property int padding: 8
    property color baseColor: "transparent"
    property color hoverColor: Theme.bg1
    readonly property alias hovered: mouse.containsMouse

    signal clicked(var mouse)

    implicitWidth: label.implicitWidth + padding * 2
    implicitHeight: 26
    color: highlighted ? highlightColor : hovered ? hoverColor : baseColor

    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: root.highlighted ? Theme.bg : root.textColor
        font: Theme.font
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => root.clicked(event)
    }
}
