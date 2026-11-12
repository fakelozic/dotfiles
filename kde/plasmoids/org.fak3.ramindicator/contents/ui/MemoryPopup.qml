import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// What opens when the RAM bar is clicked: the total, then memory per app.
Item {
    id: popup

    required property real usage        // 0 to 100
    required property color barColor
    required property string summary    // "6.6 GiB of 15.4 GiB used"
    required property real usedKib
    required property var apps          // ListModel with name, icon and kib, largest first
    required property real appsKib      // sum of the listed apps
    required property bool fresh        // false while the list still shows the previous reading

    // Whatever is in use but belongs to no listed app: the desktop, services, containers, the kernel.
    readonly property real restKib: Math.max(0, usedKib - appsKib)

    function size(kib) {
        const mib = kib / 1024;
        return mib >= 1024 ? (mib / 1024).toFixed(1) + " GiB" : Math.round(mib) + " MiB";
    }

    implicitWidth: Kirigami.Units.gridUnit * 16
    implicitHeight: column.implicitHeight + Kirigami.Units.smallSpacing * 2
    // Pin the popup to its content, so it grows and shrinks with the number of apps.
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight

    component UsageRow: Item {
        id: row
        required property string name
        required property string icon
        required property real kib

        Layout.fillWidth: true
        implicitHeight: Math.max(Kirigami.Units.iconSizes.small, nameLabel.implicitHeight) + Kirigami.Units.smallSpacing

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing * 2

            Kirigami.Icon {
                source: row.icon || "application-x-executable"
                fallback: "application-x-executable"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                id: nameLabel
                text: row.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: popup.size(row.kib)
                font.features: { "tnum": 1 }          // digits of equal width, so the column lines up
            }
        }
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: "Memory"
                font.bold: true
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: Math.round(popup.usage) + "%"
                font.bold: true
                font.features: { "tnum": 1 }
            }
        }

        Rectangle {                                   // track
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: height / 2
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

            Rectangle {                               // fill
                width: Math.max(height, parent.width * popup.usage / 100)
                height: parent.height
                radius: height / 2
                color: popup.barColor
                Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
                Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
            }
        }

        PlasmaComponents.Label {
            text: popup.summary
            opacity: 0.75
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        PlasmaComponents.Label {
            visible: popup.apps.count === 0
            text: "Reading apps…"
            opacity: 0.6
        }

        ColumnLayout {
            visible: popup.apps.count > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            opacity: popup.fresh ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            Repeater {
                model: popup.apps
                delegate: UsageRow {}
            }

            UsageRow {
                name: "System and everything else"
                icon: "computer-symbolic"
                kib: popup.restKib
                opacity: 0.75
            }
        }
    }
}
