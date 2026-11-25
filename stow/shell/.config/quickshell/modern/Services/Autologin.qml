// Applies general.autologin to the boot login path. Settings writes
// config.json only; this Service pkexecs autologin-apply.sh so the next
// reboot opens the desktop for the session account (greetd initial
// session, or getty@tty1 when greetd is not the display manager).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool running: false
    property string error: ""
    property bool wanted: false
    property string _stderr: ""

    readonly property string loginName: Quickshell.env("USER") || ""

    signal applied(bool on)

    Process {
        id: proc
        running: false
        stderr: StdioCollector {
            onStreamFinished: root._stderr = String(this.text || "").trim()
        }
        onExited: (code) => {
            proc.running = false;
            root.running = false;
            if (code === 0) {
                root.error = "";
                root.applied(root.wanted);
                return;
            }
            root.error = root._stderr.length ? root._stderr : I18n.t("settings.users.autologinFailed");
        }
    }

    function setEnabled(on) {
        const user = String(root.loginName || "").trim();
        if (root.running || !user.length)
            return;
        root.wanted = !!on;
        root.error = "";
        root._stderr = "";
        root.running = true;
        proc.running = false;
        proc.command = ["pkexec", Paths.script("autologin-apply.sh"), root.wanted ? "enable" : "disable", user];
        Qt.callLater(() => {
            if (root.running)
                proc.running = true;
        });
    }
}
