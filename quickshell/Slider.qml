import QtQuick

// A horizontal 0–1 slider. Drag or click to set it; the wheel moves it by 2%.
Item {
    id: root

    property real value: 0
    property color fill: Theme.yellow
    property bool dimmed: false

    signal moved(real value)

    implicitHeight: 16
    implicitWidth: 200

    function set(x) {
        root.moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        color: Theme.bg1

        Rectangle {
            width: parent.width * Math.min(1, root.value)
            height: parent.height
            color: root.dimmed ? Theme.muted : root.fill
        }
    }

    Rectangle {
        x: Math.round((root.width - width) * Math.min(1, root.value))
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 14
        color: mouse.pressed || mouse.containsMouse ? Theme.fg : (root.dimmed ? Theme.muted : root.fill)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onPressed: event => root.set(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.set(event.x);
        }
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.02 : -0.02))))
    }
}
