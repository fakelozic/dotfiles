//@ pragma NativeTextRendering
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The bottom bar on the BenQ display. If HDMI-A-1 is missing, it goes on the
// first display instead. The pragmas make text and icons match the GTK apps.
ShellRoot {
    PanelWindow {
        id: bar

        screen: Quickshell.screens.find(screen => screen.name === "HDMI-A-1") ?? Quickshell.screens[0]
        anchors {
            left: true
            right: true
            bottom: true
        }
        implicitHeight: 26
        color: "#fa1d2021"

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg2
        }

        Item {
            anchors.fill: parent
            anchors.topMargin: 1

            Row {
                anchors.left: parent.left
                height: parent.height
                leftPadding: 3
                spacing: 2

                Module {
                    text: "\u{f030a}"
                    textColor: hovered ? Theme.bg : Theme.blue
                    color: hovered ? Theme.blue : "transparent"
                    leftPadding: 9
                    rightPadding: 11
                    tooltip: "Apps and commands  <b>Super+D</b><br>Right-click: keyboard shortcuts"
                    onClicked: mouse => mouse.button === Qt.RightButton ? shortcuts.toggle() : launcher.toggle()
                }

                Workspaces {
                    height: parent.height
                }
                SwayMode {}
                WindowTitle {
                    output: bar.screen.name
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: parent.height
                spacing: 2

                Clock {}
                NightLight {}
                Notifications {}
            }

            Row {
                anchors.right: parent.right
                height: parent.height
                rightPadding: 3
                spacing: 2

                Media {}

                Tray {
                    height: parent.height
                }

                Module {
                    id: idle
                    readonly property bool on: idleState.on
                    text: ""
                    textColor: on ? Theme.bg : Theme.muted
                    color: on ? Theme.purple : "transparent"
                    minTextWidth: 18
                    // The cup's ink sits left of its advance; this centers it.
                    leftPadding: 8
                    rightPadding: 6
                    tooltip: on ? "Idle inhibitor on" : "Idle inhibitor off"
                    onClicked: idleState.on = !idleState.on

                    // Survives Quickshell reloading its files.
                    PersistentProperties {
                        id: idleState
                        reloadableId: "idleInhibitor"
                        property bool on: false
                    }

                    IdleInhibitor {
                        window: bar
                        enabled: idle.on
                    }
                }

                Audio {
                    id: audio
                }
                Network {}
                Cpu {
                    id: cpu
                    panel: system
                }
                Memory {
                    panel: system
                }

                SystemPanel {
                    id: system
                    source: cpu
                }

                Module {
                    text: "\u{f0425}"
                    textColor: hovered ? Theme.bg : Theme.muted
                    color: hovered ? Theme.aqua : "transparent"
                    leftPadding: 10
                    rightPadding: 10
                    tooltip: "Power"
                    onClicked: power.toggle()
                }
            }
        }
    }

    Osd {
        screen: bar.screen
        suppressed: audio.panelOpen
    }

    NotificationPopups {
        screen: bar.screen
    }

    PowerMenu {
        id: power
        screen: bar.screen
    }

    Launcher {
        id: launcher
        screen: bar.screen
        windows: windows
        clipboard: clipboard
        shortcuts: shortcuts
        wallpapers: wallpapers
        power: power
        idle: idleState
    }

    Windows {
        id: windows
        screen: bar.screen
    }

    Clipboard {
        id: clipboard
        screen: bar.screen
    }

    Shortcuts {
        id: shortcuts
        screen: bar.screen
    }

    Wallpapers {
        id: wallpapers
        screen: bar.screen
    }

    Background {}

    Polkit {
        screen: bar.screen
    }

    // A one-time tip on the first start; its button opens the shortcuts.
    Process {
        id: welcome
        command: ["notify-send", "--app-name=Quickshell", "--icon=input-keyboard", "--action=keys=Show shortcuts", "Welcome", "Super+D searches apps and commands, or click the Fedora logo on the bar. Type “shortcuts” there to see every key."]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "keys") shortcuts.toggle()
        }
    }

    Connections {
        target: Store

        function onReadyChanged() {
            if (Store.ready && !Store.welcomed) {
                Store.welcomed = true;
                welcome.running = true;
            }
        }
    }

    Lock {}
}
