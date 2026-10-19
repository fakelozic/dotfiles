import QtQuick
import Quickshell
import Quickshell.Widgets

// A tray item's menu in the bar's colors. A submenu replaces the list, with a
// row at the top to go back. Clicking outside closes it.
PopupWindow {
    id: root

    required property Item target
    property QsMenuHandle menu
    // The menu being shown and the menus it was opened from.
    property list<QsMenuHandle> stack: []
    property bool wanted: false
    // Labels line up after a check mark column when any entry has one.
    readonly property bool checkable: opener.children.values.some(entry => entry.buttonType !== QsMenuButtonType.None)

    function toggle() {
        if (wanted)
            close();
        else
            show([menu]);
    }

    function show(menus) {
        stack = menus;
        wanted = true;
        reveal.tries = 0;
        reveal.restart();
        visible = false;
    }

    function close() {
        wanted = false;
        visible = false;
        stack = [];
    }

    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    grabFocus: true
    visible: false
    implicitWidth: list.implicitWidth + 2
    implicitHeight: list.implicitHeight + 2
    color: "transparent"

    // Clicking outside the menu hides it.
    onVisibleChanged: if (!visible && !reveal.running) close()

    // The popup keeps the size it first appears with, and entries load over
    // D-Bus after a menu is opened, so show it once they are there.
    Timer {
        id: reveal
        property int tries: 0
        interval: 30
        repeat: true
        onTriggered: {
            if (opener.children.values.length > 0 || ++tries > 30) {
                stop();
                root.visible = root.wanted;
            }
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.stack.length ? root.stack[root.stack.length - 1] : null
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2

        Column {
            id: list
            x: 1
            y: 1
            topPadding: 4
            bottomPadding: 4

            MenuRow {
                visible: root.stack.length > 1
                label: "‹  Back"
                onActivated: root.show(root.stack.slice(0, -1))
            }

            Repeater {
                model: opener.children

                delegate: Loader {
                    required property QsMenuEntry modelData

                    sourceComponent: modelData.isSeparator ? separator : row

                    Component {
                        id: separator
                        Item {
                            implicitWidth: 160
                            implicitHeight: 9
                            Rectangle {
                                x: 8
                                y: 4
                                width: list.width - 16
                                height: 1
                                color: Theme.bg2
                            }
                        }
                    }

                    Component {
                        id: row
                        MenuRow {
                            entry: modelData
                            label: modelData.text.replace(/_(_)?/g, "$1")
                            onActivated: {
                                if (modelData.hasChildren) {
                                    root.show(root.stack.concat([modelData]));
                                } else {
                                    modelData.triggered();
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Item {
        id: menuRow

        property QsMenuEntry entry: null
        property string label
        readonly property bool active: entry === null || entry.enabled
        readonly property bool checked: entry !== null && entry.buttonType !== QsMenuButtonType.None
                                        && entry.checkState === Qt.Checked

        signal activated()

        implicitWidth: Math.max(160, content.implicitWidth + 20)
        implicitHeight: 26

        Rectangle {
            width: list.width - 2
            x: 1
            height: parent.height
            color: mouse.containsMouse && menuRow.active ? Theme.bg1 : "transparent"
        }

        Row {
            id: content
            x: 10
            height: parent.height
            spacing: 8

            Text {
                visible: menuRow.entry !== null && root.checkable
                width: 12
                anchors.verticalCenter: parent.verticalCenter
                text: menuRow.checked ? "✓" : ""
                color: Theme.yellow
                font: Theme.font
            }

            IconImage {
                visible: menuRow.entry !== null && menuRow.entry.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: menuRow.entry ? menuRow.entry.icon : ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: menuRow.label
                color: menuRow.active ? Theme.fg : Theme.muted
                font: Theme.font
            }
        }

        Text {
            visible: menuRow.entry !== null && menuRow.entry.hasChildren
            x: list.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: Theme.muted
            font: Theme.font
        }

        MouseArea {
            id: mouse
            width: list.width
            height: parent.height
            hoverEnabled: true
            enabled: menuRow.active
            onClicked: menuRow.activated()
        }
    }
}
