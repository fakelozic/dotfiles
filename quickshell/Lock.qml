import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The lock screen, checked against swaylock's PAM configuration.
// `qs ipc call lock lock` locks; swayidle and Super+Escape go through
// ~/.local/bin/lock-screen, which falls back to swaylock.
Scope {
    id: root

    property string password: ""
    property string message: ""
    property bool busy: false
    property int failures: 0

    signal failed()

    function lock() {
        if (sessionLock.locked)
            return;
        password = "";
        message = "";
        failures = 0;
        sessionLock.locked = true;
    }

    function submit() {
        if (busy || password === "")
            return;
        busy = true;
        message = "";
        pam.start();
    }

    PamContext {
        id: pam
        config: "swaylock"

        onPamMessage: {
            if (responseRequired)
                respond(root.password);
            else if (message !== "")
                root.message = message;
        }

        onCompleted: result => {
            root.busy = false;
            root.password = "";
            if (result === PamResult.Success) {
                root.failures = 0;
                sessionLock.locked = false;
            } else {
                root.failures++;
                root.message = root.failures > 1 ? "Wrong password (" + root.failures + ")" : "Wrong password";
                root.failed();
            }
        }

        onError: error => {
            root.busy = false;
            root.password = "";
            root.message = "Authentication error: " + PamError.toString(error);
            root.failed();
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            color: Theme.bg

            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        // For swayidle's unlock hook (`loginctl unlock-session`), as swaylock
        // unlocks on SIGUSR1.
        function unlock(): void {
            sessionLock.locked = false;
        }
        // True once the compositor has confirmed the lock.
        function secure(): bool {
            return sessionLock.secure;
        }
        function locked(): bool {
            return sessionLock.locked;
        }
    }
}
