import QtQuick
import Quickshell

// A searchable list in an overlay card, shared by the launcher and the
// clipboard, window and shortcut pickers. Typing sets query, Up/Down, Tab or
// Ctrl+J/K move, Page Up/Down jump, Enter activates the selected item and
// Escape closes. keyHandler sees each key first and returns true to take it.
// Rows are PickerRow delegates; an optional preview fills a pane on the right.
Overlay {
    id: root

    property var items: []
    property int selected: 0
    property Component delegate
    property Component preview: null
    property int previewWidth: 0
    property string icon: "\u{f0349}"
    property string placeholder: "Search"
    property string emptyText: "Nothing found"
    property var hints: []
    property var keyHandler: null
    property real size: 0.375
    property int preferredRowHeight: 50
    property alias query: search.text
    // Where the pointer was last seen. Hovering selects a row only once the
    // pointer moves, not when the list opens or scrolls under it.
    property point pointer: Qt.point(-1, -1)

    readonly property var current: items[selected] ?? null
    readonly property bool cursorAtEnd: search.cursorPosition === search.text.length
    readonly property int visibleRows: Math.max(1, Math.round(list.height / preferredRowHeight))
    readonly property int rowHeight: Math.floor(list.height / visibleRows)

    signal activated(var item)
    signal released(var event)

    function show() {
        query = "";
        selected = 0;
        pointer = Qt.point(-1, -1);
        list.positionViewAtBeginning();
        open = true;
    }

    function move(step) {
        if (items.length > 0)
            selected = (selected + step + items.length) % items.length;
    }

    function jump(step) {
        if (items.length > 0)
            selected = Math.max(0, Math.min(items.length - 1, selected + step));
    }

    function hover(index, at) {
        if (pointer.x >= 0 && (at.x !== pointer.x || at.y !== pointer.y))
            selected = index;
        pointer = at;
    }

    onQueryChanged: selected = 0
    onItemsChanged: selected = Math.max(0, Math.min(selected, items.length - 1))
    onSelectedChanged: list.positionViewAtIndex(selected, ListView.Contain)

    cardWidth: Math.round(width * size)
    cardHeight: Math.round(height * size)

    Item {
        id: header

        x: 1
        y: 1
        width: parent.width - 2
        height: 52

        Label {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            pixelSize: 18
            color: Theme.yellow
        }

        TextInput {
            id: search

            anchors.left: glyph.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fg
            selectionColor: Theme.bg2
            selectedTextColor: Theme.fg
            font.family: Theme.font.family
            font.pixelSize: 18
            font.weight: Theme.font.weight
            clip: true
            focus: root.open
            onActiveFocusChanged: cursorVisible = activeFocus

            Label {
                visible: search.text === ""
                width: search.width
                text: root.placeholder
                pixelSize: 18
                color: Theme.muted
            }

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (root.keyHandler && root.keyHandler(event)) {
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Escape)
                    root.open = false;
                else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))
                    root.move(1);
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))
                    root.move(-1);
                else if (event.key === Qt.Key_PageDown)
                    root.jump(root.visibleRows);
                else if (event.key === Qt.Key_PageUp)
                    root.jump(-root.visibleRows);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.current !== null)
                        root.activated(root.current);
                } else
                    return;
                event.accepted = true;
            }
            Keys.onReleased: event => root.released(event)
        }
    }

    Rectangle {
        id: topRule
        anchors.top: header.bottom
        x: 1
        width: parent.width - 2
        height: 1
        color: Theme.bg2
    }

    ListView {
        id: list

        anchors.top: topRule.bottom
        anchors.bottom: bottomRule.top
        x: 1
        width: parent.width - 2 - root.previewWidth
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.selected
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Theme.fast
        highlightMoveVelocity: -1
        highlightResizeDuration: 0
        highlight: Rectangle {
            color: Theme.yellow
        }
        model: ScriptModel {
            values: root.items
        }
        delegate: root.delegate
    }

    Label {
        visible: root.items.length === 0
        anchors.centerIn: list
        width: list.width - 32
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.emptyText
        color: Theme.muted
    }

    Rectangle {
        visible: root.preview !== null
        anchors.top: topRule.bottom
        anchors.bottom: bottomRule.top
        anchors.left: list.right
        width: 1
        color: Theme.bg2
    }

    Loader {
        anchors.top: topRule.bottom
        anchors.bottom: bottomRule.top
        anchors.left: list.right
        anchors.leftMargin: 1
        width: root.previewWidth - 2
        active: root.preview !== null && root.open
        sourceComponent: root.preview
    }

    Rectangle {
        id: bottomRule
        anchors.bottom: footer.top
        x: 1
        width: parent.width - 2
        height: 1
        color: Theme.bg2
    }

    Item {
        id: footer

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        x: 1
        width: parent.width - 2
        height: 30

        Hints {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            hints: root.hints
        }
    }
}
