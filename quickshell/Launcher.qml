import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "Search.js" as Search

// Searches apps and shell commands in one list; apps started most often come
// first. Typing arithmetic shows the answer, and Enter copies it. → opens an
// app's own actions, such as a new private window, and ← goes back. When
// nothing matches, Enter runs the typed text as a shell command. Opens with
// `qs ipc call launcher toggle` or the bar's menu button.
Picker {
    id: root

    // The other surfaces commands open, set by shell.qml.
    property var windows
    property var clipboard
    property var shortcuts
    property var wallpapers
    property var power
    property var idle

    // The app whose actions are listed, or null for the search.
    property var actionsOf: null

    readonly property var apps: DesktopEntries.applications.values.filter(app => !app.noDisplay)
    readonly property var commands: [
        { name: "Switch window", description: "Every open window, most recent first", glyph: "\u{f05b2}", keys: "Super+Tab", keywords: "windows alt tab focus", run: () => windows.next() },
        { name: "Clipboard history", description: "Copy something you copied before", glyph: "\u{f18fa}", keys: "Super+Shift+V", keywords: "paste copy cliphist", run: () => clipboard.toggle() },
        { name: "Keyboard shortcuts", description: "Every Sway shortcut, searchable", glyph: "\u{f097b}", keys: "", keywords: "keybindings keys help cheat sheet bindings", run: () => shortcuts.toggle() },
        { name: "Change wallpaper", description: "Pick a background from ~/walls", glyph: "\u{f02f9}", keys: "", keywords: "background wallpaper image", run: () => wallpapers.toggle() },
        { name: "Notification center", description: "Notifications you have not dismissed", glyph: "\u{f009a}", keys: "Super+N", keywords: "notifications alerts", run: () => Notifs.centerRequested() },
        { name: "Do Not Disturb", description: Notifs.dnd ? "On: popups are silenced" : "Off: popups show", glyph: "\u{f00a0}", keys: "", keywords: "dnd silence quiet notifications", run: () => Notifs.toggleDnd() },
        { name: "Night light", description: "Warm the screen colors, or turn it back", glyph: "\u{f0594}", keys: "", keywords: "redshift warm blue light wlsunset", run: () => Quickshell.execDetached(["sh", "-c", '"$HOME/.local/bin/nightlight" toggle']) },
        { name: "Stay awake", description: idle?.on ? "On: the screen will not lock" : "Off: locks after 5 minutes idle", glyph: "\u{f06ca}", keys: "", keywords: "caffeine idle inhibit coffee", run: () => idle.on = !idle.on },
        { name: "Screenshot an area", description: "Select an area; it goes to the clipboard", glyph: "\u{f0e51}", keys: "Super+Shift+S", keywords: "screenshot capture print", run: () => later("screenshot clipboard") },
        { name: "Screenshot a display", description: "Saved to Pictures/Screenshots", glyph: "\u{f0379}", keys: "Super+Z, A", keywords: "screenshot capture print monitor", run: () => later("screenshot output") },
        { name: "Pick a color", description: "Copies its hex code", glyph: "\u{f020a}", keys: "Super+Z, C", keywords: "color picker eyedropper hex", run: () => later("pick-color") },
        { name: "Lock", description: "Lock the screen", glyph: "\u{f033e}", keys: "Super+Escape", keywords: "lock screen", run: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
        { name: "Suspend", description: "Sleep until a key is pressed", glyph: "\u{f0904}", keys: "", keywords: "sleep suspend", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { name: "Log out", description: "Opens the power menu to confirm", glyph: "\u{f0343}", keys: "", keywords: "logout exit sign out power", run: () => power.choose("o") },
        { name: "Reboot", description: "Opens the power menu to confirm", glyph: "\u{f0709}", keys: "", keywords: "restart reboot power", run: () => power.choose("r") },
        { name: "Shut down", description: "Opens the power menu to confirm", glyph: "\u{f0425}", keys: "", keywords: "shutdown power off poweroff", run: () => power.choose("d") },
        { name: "Reload Sway", description: "Apply changes to the Sway config", glyph: "\u{f0453}", keys: "Super+Shift+R", keywords: "reload refresh config", run: () => Quickshell.execDetached(["swaymsg", "reload"]) }
    ]

    readonly property string q: query.trim()
    readonly property var calculation: {
        const value = Search.calculate(q);
        return value === null ? null : Search.formatNumber(value);
    }

    readonly property var results: {
        const launches = Store.launches ?? {};
        const ranked = [];
        for (const app of apps) {
            const rank = Search.rank(app.name, [app.genericName, app.id, ...app.keywords], q);
            if (rank >= 0)
                ranked.push({ rank, uses: launches[app.id] ?? 0, item: { kind: "app", name: app.name, description: app.genericName || app.comment, icon: app.icon, entry: app, more: app.actions.length > 0 } });
        }
        if (q !== "")
            for (const command of commands) {
                const rank = Search.rank(command.name, [command.keywords, command.description], q);
                if (rank >= 0)
                    ranked.push({ rank, uses: 0, item: Object.assign({ kind: "command" }, command) });
            }
        ranked.sort((a, b) => a.rank - b.rank || b.uses - a.uses || a.item.name.localeCompare(b.item.name));
        const items = ranked.map(match => match.item);
        if (calculation !== null)
            items.unshift({ kind: "calc", name: "= " + calculation, description: "Enter copies the answer", glyph: "\u{f00ec}", value: calculation });
        if (items.length === 0 && q !== "")
            items.push({ kind: "run", name: "Run " + q, description: "As a shell command", glyph: "\u{f018d}" });
        return items;
    }

    readonly property var actionItems: actionsOf === null ? [] : [...actionsOf.actions]
        .filter(action => Search.rank(action.name, [], q) >= 0)
        .map(action => ({ kind: "action", name: action.name, description: actionsOf.name, icon: action.icon || actionsOf.icon, action }))

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        actionsOf = null;
        show();
    }

    // Runs a script from ~/.local/bin once the launcher has faded, so it is
    // not in the screenshot.
    function later(script) {
        Quickshell.execDetached(["sh", "-c", 'sleep 0.25; exec "$HOME/.local/bin/"' + script]);
    }

    function start(app) {
        Store.recordLaunch(app.id);
        if (app.runInTerminal)
            Quickshell.execDetached(["alacritty", "-e", ...app.command]);
        else
            app.execute();
    }

    function openActions(item) {
        if (item?.kind !== "app" || !item.more)
            return false;
        actionsOf = item.entry;
        query = "";
        return true;
    }

    function back() {
        const entry = actionsOf;
        actionsOf = null;
        query = "";
        selected = Math.max(0, items.findIndex(item => item.entry === entry));
    }

    name: "launcher"
    items: actionsOf !== null ? actionItems : results
    icon: actionsOf !== null ? "\u{f0142}" : "\u{f0349}"
    placeholder: actionsOf !== null ? actionsOf.name + " actions" : "Search apps and commands, or type 2+2"
    emptyText: actionsOf !== null ? "No matching actions" : "No applications"
    hints: actionsOf !== null ? [["Enter", "run"], ["←", "back"], ["Esc", "close"]]
        : current?.more ? [["Enter", "open"], ["→", "actions"], ["↑↓", "move"], ["Esc", "close"]]
        : [["Enter", current?.kind === "calc" ? "copy" : "open"], ["↑↓", "move"], ["Esc", "close"]]

    keyHandler: event => {
        if (event.key === Qt.Key_Right && cursorAtEnd)
            return openActions(current);
        if (actionsOf !== null && q === "" && (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace)) {
            back();
            return true;
        }
        return false;
    }

    onActivated: item => {
        open = false;
        if (item.kind === "app")
            start(item.entry);
        else if (item.kind === "action") {
            Store.recordLaunch(actionsOf.id);
            item.action.execute();
        } else if (item.kind === "command")
            item.run();
        else if (item.kind === "calc")
            Quickshell.execDetached(["wl-copy", "--", item.value]);
        else if (item.kind === "run")
            Quickshell.execDetached(["sh", "-c", q]);
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }

    delegate: PickerRow {
        id: row

        picker: root

        IconImage {
            id: icon
            visible: row.modelData.glyph === undefined
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 32
            source: visible ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
        }

        Label {
            visible: row.modelData.glyph !== undefined
            anchors.centerIn: icon
            text: row.modelData.glyph ?? ""
            pixelSize: 22
            color: row.current ? Theme.bg : Theme.yellow
        }

        Label {
            id: title
            anchors.left: icon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, row.width - x - tail.width - 28)
            text: row.modelData.name
            pixelSize: 16
            color: row.fg
        }

        Label {
            anchors.left: title.right
            anchors.leftMargin: 10
            anchors.right: tail.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.description ?? ""
            pixelSize: 16
            color: row.dim
            font.weight: Font.Normal
        }

        Label {
            id: tail
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.more ? "\u{f0142}" : row.modelData.keys ?? ""
            pixelSize: 13
            color: row.dim
        }
    }
}
