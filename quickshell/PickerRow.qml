import QtQuick

// One row of a Picker. It follows the picker's selection, selects itself when
// the pointer moves over it and activates on click. fg and dim are the text
// colors to use on and off the highlight.
Item {
    id: row

    required property var modelData
    required property int index
    required property Picker picker

    readonly property bool current: index === picker.selected
    readonly property color fg: current ? Theme.bg : Theme.fg
    readonly property color dim: current ? Theme.bg1 : Theme.muted

    width: ListView.view ? ListView.view.width : 0
    height: picker.rowHeight

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: mouse => row.picker.hover(row.index, mapToItem(null, mouse.x, mouse.y))
        onClicked: {
            row.picker.selected = row.index;
            row.picker.activated(row.modelData);
        }
    }
}
