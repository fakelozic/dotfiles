import QtQuick
import Quickshell
import Quickshell.Wayland

// The wallpaper on every display, cross-fading when it changes. It sits on the
// layer just above swaybg, so Sway's own `output * bg` still shows if
// Quickshell is not running.
Scope {
    id: root

    readonly property string shown: Store.wallpaper || Store.defaultWallpaper || ""

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-wallpaper"
            color: Theme.bg
            visible: Store.ready ?? false

            // The old picture stays underneath while the new one fades in.
            Image {
                id: below
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(window.width, window.height)
                asynchronous: true
            }

            Image {
                id: above
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(window.width, window.height)
                asynchronous: true
                source: root.shown ? "file://" + root.shown : ""

                onSourceChanged: opacity = 0
                onStatusChanged: if (status === Image.Ready) fadeIn.restart()

                NumberAnimation {
                    id: fadeIn
                    target: above
                    property: "opacity"
                    to: 1
                    duration: 300
                    easing.type: Easing.OutCubic
                    onFinished: below.source = above.source
                }
            }
        }
    }
}
