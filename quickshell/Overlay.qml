import QtQuick
import Quickshell
import Quickshell.Wayland

// A card in the middle of the screen over a dimmed backdrop, the base of the
// launcher, pickers and polkit prompt. It takes the keyboard while open, and a
// click outside closes it unless dismissable is false. The card fades and
// grows in briefly when it opens.
PanelWindow {
    id: root

    property bool open: false
    property bool dismissable: true
    property string name: "overlay"
    property int cardWidth: 400
    property int cardHeight: 300
    readonly property alias card: card
    default property alias content: card.data

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-" + name
    color: "transparent"
    visible: open || backdrop.opacity > 0

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.bg
        opacity: root.open ? 0.6 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: if (root.dismissable) root.open = false
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: root.cardWidth
        height: root.cardHeight
        color: Theme.bg0
        border.width: 1
        border.color: Theme.bg2
        opacity: backdrop.opacity / 0.6
        scale: 0.97 + 0.03 * opacity

        // Keeps clicks inside the card from closing it.
        MouseArea {
            anchors.fill: parent
        }
    }
}
