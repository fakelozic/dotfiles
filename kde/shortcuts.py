#!/usr/bin/env python3
"""Sway-style KDE shortcuts, applied through kglobalaccel so they take effect
in the running Plasma session (editing kglobalshortcutsrc by hand does not:
KWin keeps the shortcuts in memory and writes its own copy back).

Usage: shortcuts.py [--check]
  --check  only report which shortcuts differ; change nothing.
"""
import sys

META, SHIFT, CTRL, ALT = 0x10000000, 0x02000000, 0x04000000, 0x08000000
NAMED_KEYS = {
    **{f"F{n}": 0x01000030 + n - 1 for n in range(1, 13)},
    "Return": 0x01000004,
    "Enter": 0x01000005,
    "PgUp": 0x01000016,
    "PgDown": 0x01000017,
}
MODIFIERS = {"Meta": META, "Shift": SHIFT, "Ctrl": CTRL, "Alt": ALT}

# (component, action, component name, action name, keys)
SHORTCUTS = [
    *[("kwin", f"Switch to Desktop {n}", "KWin", f"Switch to Desktop {n}",
       [f"Ctrl+F{n}", f"Meta+{n}", f"Meta+F{n}"]) for n in range(1, 5)],
    *[("kwin", f"Switch to Desktop {n}", "KWin", f"Switch to Desktop {n}",
       [f"Meta+{n}"]) for n in (5, 6)],
    # KDE stores both the shifted character and Shift+digit for US layouts.
    *[("kwin", f"Window to Desktop {n}", "KWin", f"Window to Desktop {n}",
       [f"Meta+{char}", f"Meta+Shift+{n}"]) for n, char in zip(range(1, 7), "!@#$%^")],
    ("kwin", "Window Close", "KWin", "Close Window", ["Alt+F4", "Meta+Shift+Q"]),
    ("kwin", "Window Fullscreen", "KWin", "Make Window Fullscreen", ["Meta+Shift+F"]),
    ("kwin", "Window Maximize", "KWin", "Maximize Window", ["Meta+F", "Meta+PgUp"]),
    ("com.mitchellh.ghostty.desktop", "_launch", "Ghostty", "Launch", ["Meta+Return"]),
]


def key_code(sequence):
    """'Meta+Shift+Q' -> the integer Qt uses for that key combination."""
    *mods, key = sequence.split("+") if sequence != "Meta++" else ["Meta", "+"]
    code = 0
    for mod in mods:
        code |= MODIFIERS[mod]
    if key in NAMED_KEYS:
        return code | NAMED_KEYS[key]
    if len(key) != 1:
        raise ValueError(f"unknown key {key!r} in {sequence!r}")
    return code | ord(key.upper())


def main(argv):
    check = "--check" in argv
    import dbus  # imported here so the tests can use key_code() without D-Bus

    bus = dbus.SessionBus()
    accel = dbus.Interface(bus.get_object("org.kde.kglobalaccel", "/kglobalaccel"),
                           "org.kde.KGlobalAccel")

    def as_dbus(codes):
        return dbus.Array([dbus.Struct([dbus.Array([c, 0, 0, 0], signature="i")])
                           for c in codes], signature="(ai)")

    different = 0
    for component, action, component_name, action_name, keys in SHORTCUTS:
        action_id = dbus.Array([component, action, component_name, action_name], signature="s")
        wanted = [key_code(k) for k in keys]
        current = [int(k[0][0]) for k in accel.shortcutKeys(action_id)]
        if sorted(current) == sorted(wanted):  # KDE returns them in no fixed order
            continue
        different += 1
        print(f"{'differs' if check else 'setting'}: {action_name} -> {' / '.join(keys)}")
        if check:
            continue
        if component == "kwin":
            accel.setForeignShortcutKeys(action_id, as_dbus(wanted))
        else:
            # An application launcher: register it, then set it as the user's choice.
            accel.doRegister(action_id)
            accel.setShortcutKeys(action_id, as_dbus(wanted), dbus.UInt32(2 | 4))
    if not different:
        print("All shortcuts already match.")
    return 1 if check and different else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
