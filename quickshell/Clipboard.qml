import QtQuick
import Quickshell
import Quickshell.Io

// The cliphist history, newest first, with the selected entry shown in full on
// the right: text as it was copied, images as a picture. Enter copies it
// again, Shift+Delete forgets it, and Ctrl+Shift+Delete twice clears the
// history. Opens with `qs ipc call clipboard toggle`. Decoded images are kept
// in $XDG_RUNTIME_DIR, which only this user can read and which is emptied at
// logout.
Picker {
    id: root

    readonly property string cache: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-clipboard"
    property var entries: []
    // Whether this listing's images are decoded, and a counter bumped each
    // time they are, so thumbnails load again.
    property bool imagesReady: false
    property int imagesVersion: 0
    property string fullText: ""
    property bool confirmClear: false

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        confirmClear = false;
        imagesReady = false;
        show();
        list.running = true;
    }

    function imageFile(entry) {
        return `file://${cache}/${entry.id}.${entry.ext}?${imagesVersion}`;
    }

    // Runs cliphist with an entry's history line on its input, as
    // `cliphist decode` and `cliphist delete` expect.
    function withLine(entry, script) {
        Quickshell.execDetached(["sh", "-c", `printf '%s' "$1" | ${script}`, "sh", entry.line]);
    }

    name: "clipboard"
    icon: "\u{f18fa}"
    placeholder: "Search clipboard history"
    emptyText: entries.length === 0 ? "Nothing copied yet" : "No matching entries"
    previewWidth: Math.round(cardWidth * 0.45)
    hints: confirmClear ? [["Ctrl+Shift+Del", "again to clear everything"], ["Esc", "cancel"]]
        : [["Enter", "copy"], ["Shift+Del", "forget"], ["Ctrl+Shift+Del", "clear all"], ["Esc", "close"]]
    items: {
        const words = query.trim().toLowerCase().split(/\s+/).filter(word => word !== "");
        return entries.filter(entry => words.every(word => (entry.image ? "image " + entry.text : entry.text).toLowerCase().includes(word)));
    }

    onActivated: entry => {
        open = false;
        withLine(entry, "cliphist decode | wl-copy");
    }

    onCurrentChanged: {
        fullText = "";
        if (current !== null && !current.image)
            decodeTimer.restart();
    }

    keyHandler: event => {
        if (event.key !== Qt.Key_Delete || !(event.modifiers & Qt.ShiftModifier))
            return false;
        if (event.modifiers & Qt.ControlModifier) {
            if (!confirmClear) {
                confirmClear = true;
                confirmTimer.restart();
                return true;
            }
            confirmClear = false;
            entries = [];
            Quickshell.execDetached(["cliphist", "wipe"]);
        } else if (current !== null) {
            const gone = current;
            entries = entries.filter(entry => entry !== gone);
            withLine(gone, "cliphist delete");
        }
        return true;
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.toggle();
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmClear = false
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const preview = line.slice(tab + 1);
                    const image = preview.match(/^\[\[ binary data (.+?) (png|jpeg|jpg|webp|bmp|gif) (\d+)x(\d+) \]\]$/);
                    parsed.push({
                        id: line.slice(0, tab),
                        line,
                        image: image !== null,
                        ext: image ? image[2] : "",
                        text: image ? `${image[3]}×${image[4]} · ${image[1]}` : preview
                    });
                }
                root.entries = parsed;
                const images = parsed.filter(entry => entry.image).slice(0, 60).map(entry => `${entry.id}.${entry.ext}`);
                if (images.length === 0)
                    root.imagesReady = true;
                else {
                    decodeImages.command = ["sh", "-c", 'dir=$1; shift; mkdir -p -m 700 "$dir" && cd "$dir" && for f; do [ -s "$f" ] || cliphist decode "${f%.*}" > "$f"; done', "sh", root.cache, ...images];
                    decodeImages.running = true;
                }
            }
        }
    }

    Process {
        id: decodeImages
        onExited: {
            root.imagesVersion++;
            root.imagesReady = true;
        }
    }

    // Waits for the selection to settle before decoding its full text.
    Timer {
        id: decodeTimer
        interval: 60
        onTriggered: if (root.current !== null) {
            decodeText.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode | head -c 20000", "sh", root.current.line];
            decodeText.running = true;
        }
    }

    Process {
        id: decodeText
        stdout: StdioCollector {
            onStreamFinished: root.fullText = text
        }
    }

    delegate: PickerRow {
        id: row

        picker: root

        Image {
            id: thumb
            visible: row.modelData.image
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 48 : 0
            height: row.height - 14
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 96
            source: visible && root.imagesReady ? root.imageFile(row.modelData) : ""
        }

        Label {
            anchors.left: thumb.right
            anchors.leftMargin: row.modelData.image ? 12 : 0
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.image ? "Image  " + row.modelData.text : row.modelData.text
            pixelSize: 15
            color: row.modelData.image ? row.dim : row.fg
            font.weight: Font.Normal
            maximumLineCount: 1
        }
    }

    preview: Item {
        Image {
            visible: root.current?.image ?? false
            anchors.fill: parent
            anchors.margins: 16
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: visible && root.imagesReady ? root.imageFile(root.current) : ""
        }

        Flickable {
            visible: !(root.current?.image ?? true)
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: body
                width: parent.width
                text: root.fullText || (root.current?.text ?? "")
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Theme.fg
                font.family: Theme.font.family
                font.pixelSize: 14
            }
        }
    }
}
