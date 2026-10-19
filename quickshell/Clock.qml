import QtQuick
import Quickshell

// Date and time with seconds. Click for the calendar.
Module {
    id: root

    text: "\u{f0954}  " + Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm:ss")
    textColor: Theme.yellow
    leftPadding: 7
    rightPadding: 7

    onClicked: panel.toggle()

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    CalendarPanel {
        id: panel
        source: root
        now: clock.date
    }
}
