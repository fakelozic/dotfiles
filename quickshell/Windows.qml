import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Widgets
import "Search.js" as Search

// Every open window, most recently focused first, with the previous one
// selected so Enter flips back to it. Opens with `qs ipc call windows next`;
// calling it again while open moves down, so holding Super and pressing Tab
// walks the list and letting go of Super switches. Ctrl+W closes a window.
Picker {
    id: root

    // Container ids, most recently focused first.
    property var recent: []
    property var windows: []
    // How many times Tab moved the selection since opening.
    property int steps: 0

    function next() {
        if (open) {
            move(1);
            steps++;
            return;
        }
        steps = 0;
        show();
        tree.running = true;
    }

    function focus(window) {
        open = false;
        I3.dispatch(`[con_id=${window.id}] focus`);
    }

    // Windows in the tree under node, with the workspace each is on.
    function collect(node, workspace, out) {
        if (node.type === "workspace")
            workspace = node.name === "__i3_scratch" ? "Scratchpad" : node.name;
        if ((node.type === "con" || node.type === "floating_con") && node.pid && (node.app_id || node.window_properties)) {
            const appId = node.app_id ?? node.window_properties?.class ?? "";
            const entry = DesktopEntries.heuristicLookup(appId);
            out.push({
                id: node.id,
                title: node.name ?? "",
                app: entry?.name ?? appId,
                icon: entry?.icon ?? appId,
                workspace,
                focused: node.focused
            });
        }
        for (const child of [...(node.nodes ?? []), ...(node.floating_nodes ?? [])])
            collect(child, workspace, out);
        return out;
    }

    function order(list) {
        const at = id => {
            const index = recent.indexOf(id);
            return index < 0 ? Infinity : index;
        };
        return list.sort((a, b) => b.focused - a.focused || at(a.id) - at(b.id) || a.workspace.localeCompare(b.workspace, undefined, { numeric: true }) || a.id - b.id);
    }

    name: "windows"
    icon: "\u{f05b2}"
    placeholder: "Search open windows"
    emptyText: windows.length === 0 ? "No open windows" : "No matching windows"
    hints: [["Enter", "switch"], ["Tab", "next"], ["Ctrl+W", "close window"], ["Esc", "cancel"]]
    items: query.trim() === "" ? windows : windows.filter(window => Search.rank(window.title, [window.app, window.workspace], query) >= 0)

    onActivated: window => focus(window)

    // Letting go of Super after walking the list with Super+Tab switches.
    onReleased: event => {
        if (steps > 0 && (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) && current !== null)
            focus(current);
    }

    keyHandler: event => {
        if (event.key === Qt.Key_W && event.modifiers & Qt.ControlModifier && current !== null) {
            I3.dispatch(`[con_id=${current.id}] kill`);
            windows = windows.filter(window => window.id !== current.id);
            return true;
        }
        return false;
    }

    IpcHandler {
        target: "windows"

        function next(): void {
            root.next();
        }

        function close(): void {
            root.open = false;
        }
    }

    Process {
        id: tree
        command: ["swaymsg", "-r", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = root.order(root.collect(JSON.parse(text), "", []));
                } catch (error) {
                    console.warn("windows: could not read the Sway tree:", error);
                }
                root.windows = list;
                // The focused window is first; start on the one before it.
                root.selected = list.length > 1 && list[0].focused ? 1 : 0;
            }
        }
    }

    I3IpcListener {
        subscriptions: ["window"]
        onIpcEvent: event => {
            const data = JSON.parse(event.data);
            const id = data.container?.id;
            if (id === undefined)
                return;
            if (data.change === "focus")
                root.recent = [id, ...root.recent.filter(other => other !== id)].slice(0, 100);
            else if (data.change === "close")
                root.recent = root.recent.filter(other => other !== id);
        }
    }

    delegate: PickerRow {
        id: row

        picker: root

        IconImage {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 32
            source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
        }

        Label {
            id: title
            anchors.left: icon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, row.width - x - badge.width - 120)
            text: row.modelData.title || row.modelData.app
            pixelSize: 16
            color: row.fg
        }

        Label {
            anchors.left: title.right
            anchors.leftMargin: 10
            anchors.right: badge.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.app
            pixelSize: 16
            color: row.dim
            font.weight: Font.Normal
        }

        // The workspace, yellow for the window that has focus now.
        Rectangle {
            id: badge
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(26, number.implicitWidth + 12)
            height: 22
            color: row.current ? Theme.bg : row.modelData.focused ? Theme.yellow : Theme.bg1

            Label {
                id: number
                anchors.centerIn: parent
                text: row.modelData.workspace
                pixelSize: 13
                color: row.current ? Theme.yellow : row.modelData.focused ? Theme.bg : Theme.fg
            }
        }
    }
}
