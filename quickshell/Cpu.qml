import QtQuick

// CPU usage over the last few seconds. Click for the system panel.
Module {
    id: root

    required property SystemPanel panel

    text: SysStats.cpu.length ? "  " + SysStats.cpu[0] + "%" : ""
    textColor: Theme.muted
    tooltip: panel.open ? "" : "CPU " + (SysStats.cpu[0] ?? 0) + "%"

    onClicked: panel.toggle(root)
}
