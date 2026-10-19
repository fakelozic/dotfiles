import QtQuick

// Today's date and a month calendar. The arrows change the month; clicking
// the month name goes back to this month.
Panel {
    id: root

    required property date now
    // Months away from the current one.
    property int offset: 0

    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek
    readonly property int lead: (shown.getDay() - firstDay + 7) % 7
    readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()

    boxWidth: 300
    onOpenChanged: if (open) offset = 0

    // ISO 8601 week number.
    function week(day) {
        const d = new Date(Date.UTC(day.getFullYear(), day.getMonth(), day.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

    Column {
        width: parent.width
        spacing: 2

        Label {
            text: Qt.formatDateTime(root.now, "HH:mm:ss")
            pixelSize: 28
            bold: true
            color: Theme.yellow
        }

        Label {
            text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
        }

        Label {
            text: Qt.formatDate(root.now, "yyyy-MM-dd") + "  ·  week " + root.week(root.now)
            color: Theme.muted
        }
    }

    Item {
        width: parent.width
        height: 26

        Button {
            text: "\u{f0141}"
            onClicked: root.offset--
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            textColor: root.offset === 0 ? Theme.fg : Theme.aqua
            onClicked: root.offset = 0
        }

        Button {
            anchors.right: parent.right
            text: "\u{f0142}"
            onClicked: root.offset++
        }
    }

    Grid {
        id: grid

        readonly property real cell: width / 7

        width: parent.width
        columns: 7

        Repeater {
            model: 7

            delegate: Label {
                required property int index

                width: grid.cell
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                color: Theme.muted
            }
        }

        Repeater {
            model: root.lead + root.days

            delegate: Rectangle {
                required property int index

                readonly property int day: index - root.lead + 1
                readonly property bool today: root.offset === 0 && day === root.now.getDate()

                width: grid.cell
                height: 26
                color: today ? Theme.yellow : "transparent"

                Label {
                    anchors.centerIn: parent
                    text: parent.day > 0 ? parent.day : ""
                    color: parent.today ? Theme.bg : Theme.fg
                }
            }
        }
    }
}
