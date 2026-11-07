import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    TaskManager.VirtualDesktopInfo { id: desktops }

    // All windows on all desktops, to know which desktops have something open.
    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    property var occupied: ({})
    function recount() {
        const o = {};
        for (let i = 0; i < windows.count; i++) {
            const w = windows.objectAt(i);
            if (!w) continue;
            if (w.onAll) { for (const id of desktops.desktopIds) o[id] = true; continue; }
            for (const id of (w.desks || [])) o[id] = true;
        }
        occupied = o;
    }
    Instantiator {
        id: windows
        model: tasks
        delegate: QtObject {
            property var desks: model.VirtualDesktops
            property bool onAll: model.IsOnAllVirtualDesktops === true
            onDesksChanged: Qt.callLater(root.recount)
            onOnAllChanged: Qt.callLater(root.recount)
        }
        onObjectAdded: Qt.callLater(root.recount)
        onObjectRemoved: Qt.callLater(root.recount)
    }

    function invoke(name) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/component/kwin",
            iface: "org.kde.kglobalaccel.Component",
            member: "invokeShortcut",
            arguments: [name]
        });
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    fullRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        acceptedButtons: Qt.NoButton
        // Scroll to move between desktops.
        property real wheelAccum: 0
        onWheel: wheel => {
            wheelAccum += wheel.angleDelta.y || wheel.angleDelta.x;
            while (wheelAccum >= 120) { wheelAccum -= 120; root.invoke("Switch to Previous Desktop"); }
            while (wheelAccum <= -120) { wheelAccum += 120; root.invoke("Switch to Next Desktop"); }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: desktops.desktopIds
                delegate: MouseArea {
                    id: cell
                    required property string modelData
                    required property int index
                    readonly property bool current: modelData === desktops.currentDesktop
                    readonly property bool busy: root.occupied[modelData] === true
                    // Square cell with softly rounded corners.
                    Layout.preferredWidth: Math.round(label.implicitHeight * 1.25)
                    Layout.preferredHeight: Layout.preferredWidth
                    hoverEnabled: true
                    onClicked: root.invoke("Switch to Desktop " + (index + 1))

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Kirigami.Theme.textColor
                        opacity: cell.current ? 0.16 : (cell.containsMouse ? 0.08 : 0)
                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    }
                    PlasmaComponents.Label {
                        id: label
                        anchors.centerIn: parent
                        text: index + 1
                        // Same font as the panel clock.
                        font.family: "JetBrainsMono Nerd Font"
                        font.pointSize: 12
                        color: Kirigami.Theme.textColor
                        opacity: cell.current ? 1 : (cell.busy ? 0.75 : 0.35)
                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    }
                }
            }
        }
    }
}
