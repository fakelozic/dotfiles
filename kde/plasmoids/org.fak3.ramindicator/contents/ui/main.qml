import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.process as Process

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

    // ---- Memory per app, for the popup ----
    // Polling every process is not free, so the model only runs while the popup is open,
    // or while the pointer is on the bar so that it is warm by the time the click lands.
    property bool hovered: false
    readonly property bool watching: expanded || hovered
    property double watchingSince: 0
    // After a pause the model first repeats its previous reading; the list is drawn dimmed until a new one arrives.
    property bool appsFresh: false
    property real appsKib: 0                    // sum of the listed apps
    readonly property real minAppKib: 10 * 1024 // smaller apps are left to "everything else"

    ListModel { id: appList }                   // name, icon, kib; largest first

    Process.ApplicationDataModel {
        id: appModel
        enabled: root.watching
        enabledAttributes: ["appName", "iconName", "memory"]
        onDataChanged: {
            if (root.watching && Date.now() - root.watchingSince > 1000) root.appsFresh = true;
            collect.start();
        }
        onRowsInserted: collect.start()
        onRowsRemoved: collect.start()
        onModelReset: collect.start()
    }
    Timer { id: collect; interval: 200; onTriggered: if (root.watching) root.collectApps() }

    onWatchingChanged: {
        if (watching) {
            watchingSince = Date.now();
            collectApps();
        } else {
            appsFresh = false;
        }
    }

    function collectApps() {
        const value = Process.ProcessDataModel.Value;
        const rows = [];
        for (let r = 0; r < appModel.rowCount(); r++) {
            rows.push({
                name: String(appModel.data(appModel.index(r, 0), value) || ""),
                icon: String(appModel.data(appModel.index(r, 1), value) || ""),
                kib: Number(appModel.data(appModel.index(r, 2), value)) || 0
            });
        }

        // One app can own several rows, and two kinds of helper group have no app name of their own:
        // "surface" is whatever runs inside Ghostty's terminals, "agents-…" are agents started by T3 Code.
        const t3 = rows.find(a => a.name.startsWith("T3 Code"));
        const merged = new Map();
        for (const a of rows) {
            let name = a.name;
            if (name === "surface") name = "Ghostty";
            else if (/^agents-[0-9a-f]+$/.test(name)) name = t3 ? t3.name : "T3 Code";
            const seen = merged.get(name);
            if (seen) {
                seen.kib += a.kib;
                if (!seen.icon) seen.icon = a.icon;
            } else {
                merged.set(name, { name: name, icon: a.icon, kib: a.kib });
            }
        }
        const list = Array.from(merged.values()).filter(a => a.kib >= minAppKib).sort((a, b) => b.kib - a.kib);

        // Update the rows in place, so the popup does not rebuild itself on every reading.
        let sum = 0;
        for (let i = 0; i < list.length; i++) {
            sum += list[i].kib;
            if (i < appList.count) appList.set(i, list[i]);
            else appList.append(list[i]);
        }
        while (appList.count > list.length) appList.remove(appList.count - 1);
        appsKib = sum;
    }

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Memory " + Math.round(usage) + "%"
    toolTipSubText: used.formattedValue + " of " + total.formattedValue + " used"

    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onContainsMouseChanged: root.hovered = containsMouse
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

    fullRepresentation: MemoryPopup {
        usage: root.usage
        barColor: root.levelColor(root.usage)
        summary: used.formattedValue + " of " + total.formattedValue + " used"
        usedKib: (Number(used.value) || 0) / 1024
        apps: appList
        appsKib: root.appsKib
        fresh: root.appsFresh
    }
}
