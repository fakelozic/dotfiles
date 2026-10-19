import QtQuick
import Quickshell
import Quickshell.Io

// Flip through the pictures in ~/walls and ~/Pictures/Wallpapers. Enter or a
// click on the selected one makes it the wallpaper; Escape leaves it as it
// was. Opens from the launcher ("Change wallpaper").
Overlay {
    id: root

    property var files: []
    property int selected: 0

    readonly property int thumbWidth: Math.round(cardWidth / 4.2)

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        open = true;
        find.running = true;
    }

    function keep() {
        if (files.length === 0)
            return;
        Store.wallpaper = files[selected];
        open = false;
    }

    function move(step) {
        if (files.length > 0)
            selected = Math.max(0, Math.min(files.length - 1, selected + step));
    }

    name: "wallpapers"
    cardWidth: Math.round(width * 0.6)
    cardHeight: Math.round(thumbWidth * 9 / 16) + 150

    IpcHandler {
        target: "wallpapers"

        function toggle(): void {
            root.toggle();
        }
    }

    Process {
        id: find
        command: ["sh", "-c", 'find "$HOME/walls" "$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) 2>/dev/null | sort']
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(line => line !== "");
                const current = Store.wallpaper || Store.defaultWallpaper;
                root.selected = Math.max(0, root.files.indexOf(current));
                strip.positionViewAtIndex(root.selected, ListView.Center);
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: root.open

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root.open = false;
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab)
                root.move(-1);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab)
                root.move(1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.keep();
            else
                return;
            event.accepted = true;
        }

        Label {
            id: heading
            x: 20
            y: 18
            text: "\u{f02f9}  Wallpaper"
            pixelSize: 18
            color: Theme.yellow
        }

        Label {
            anchors.left: heading.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.baseline: heading.baseline
            text: root.files.length > 0 ? root.files[root.selected].split("/").pop() : ""
            pixelSize: 15
            color: Theme.muted
            font.weight: Font.Normal
        }

        ListView {
            id: strip

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 4
            height: Math.round(root.thumbWidth * 9 / 16) + 16
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            model: root.files
            currentIndex: root.selected
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - root.thumbWidth / 2
            preferredHighlightEnd: width / 2 + root.thumbWidth / 2
            highlightMoveDuration: Theme.normal
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: tile

                required property string modelData
                required property int index
                readonly property bool current: index === root.selected

                width: root.thumbWidth
                height: strip.height

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: Math.round(width * 9 / 16)
                    color: Theme.bg1
                    border.width: 2
                    border.color: tile.current ? Theme.yellow : "transparent"
                    scale: tile.current ? 1 : 0.88
                    opacity: tile.current ? 1 : 0.6

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.normal
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.normal
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: root.thumbWidth * 2
                        source: "file://" + tile.modelData
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (tile.current)
                            root.keep();
                        else
                            root.selected = tile.index;
                    }
                }
            }
        }

        Label {
            visible: root.files.length === 0
            anchors.centerIn: strip
            text: "Put pictures in ~/walls to choose from them here"
            color: Theme.muted
        }

        Hints {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            hints: [["←→", "browse"], ["Enter", "keep"], ["Esc", "cancel"]]
        }
    }
}
