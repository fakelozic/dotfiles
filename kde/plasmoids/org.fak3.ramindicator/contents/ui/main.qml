import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    Sensors.Sensor { id: percent; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: used;    sensorId: "memory/physical/used";        updateRateLimit: 2000 }
    Sensors.Sensor { id: total;   sensorId: "memory/physical/total" }

    readonly property real usage: Math.max(0, Math.min(100, Number(percent.value) || 0))

    // Gruvbox blue -> green -> yellow -> red, blended between these usage points.
    readonly property var stops: [
        { at: 30, color: "#83a598" },
        { at: 55, color: "#b8bb26" },
        { at: 75, color: "#fabd2f" },
        { at: 85, color: "#fb4934" }
    ]
    function levelColor(p) {
        if (p <= stops[0].at) return stops[0].color;
        for (let i = 1; i < stops.length; i++) {
            if (p <= stops[i].at) {
                const a = Qt.color(stops[i - 1].color), b = Qt.color(stops[i].color);
                const t = (p - stops[i - 1].at) / (stops[i].at - stops[i - 1].at);
                return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
            }
        }
        return stops[stops.length - 1].color;
    }

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Memory " + Math.round(usage) + "%"
    toolTipSubText: used.formattedValue + " of " + total.formattedValue + " used"

    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing * 1.5

            Rectangle {                                   // track
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                Layout.preferredHeight: 6
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

                Rectangle {                               // fill
                    width: Math.max(height, parent.width * root.usage / 100)
                    height: parent.height
                    radius: height / 2
                    color: root.levelColor(root.usage)
                    Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
                    Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
                }
            }

            PlasmaComponents.Label {
                id: percentLabel
                text: Math.round(root.usage)
                // Same font as the panel clock.
                font.family: "JetBrainsMono Nerd Font"
                font.pointSize: 12
                font.weight: Font.Normal
                // Fixed width so the panel does not shift when the number changes.
                Layout.preferredWidth: metrics.width
                horizontalAlignment: Text.AlignLeft
                TextMetrics { id: metrics; text: "100"; font: percentLabel.font }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        PlasmaComponents.Label {
            text: "Memory"
            font.bold: true
        }
        PlasmaComponents.Label {
            text: used.formattedValue + " of " + total.formattedValue + " used (" + Math.round(root.usage) + "%)"
        }
    }
}
