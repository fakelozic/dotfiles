import QtQuick

// RAM in use; turns red at 81%. Click for the system panel.
Module {
    id: root

    required property SystemPanel panel

    text: SysStats.memPercent < 0 ? "" : "  " + SysStats.memPercent + "%"
    textColor: SysStats.memPercent >= 81 ? Theme.red : Theme.muted
    tooltip: panel.open ? "" : (SysStats.memUsed / 1048576).toFixed(1) + " GiB used"

    onClicked: panel.toggle(root)
}
