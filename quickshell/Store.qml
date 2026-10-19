pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the shell remembers between sessions, in
// ~/.local/state/quickshell/dotfiles.json: how often each app was started from
// the launcher, the chosen wallpaper and whether the welcome tip was shown.
Singleton {
    id: root

    readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    readonly property string defaultWallpaper: Quickshell.env("HOME") + "/walls/wallg.png"
    property bool ready: false
    property alias launches: adapter.launches
    property alias wallpaper: adapter.wallpaper
    property alias welcomed: adapter.welcomed

    function recordLaunch(id) {
        const launches = Object.assign({}, adapter.launches);
        launches[id] = (launches[id] ?? 0) + 1;
        adapter.launches = launches;
    }

    Process {
        id: mkdir
        running: true
        command: ["mkdir", "-p", root.directory]
        onExited: file.path = root.directory + "/dotfiles.json"
    }

    FileView {
        id: file

        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.ready = true;
        }
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property var launches: ({})
            property string wallpaper: ""
            property bool welcomed: false
        }
    }
}
