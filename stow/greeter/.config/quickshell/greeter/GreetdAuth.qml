// Greetd lives only in this package. Importing it in the desktop
// tree would fail hosts that never installed greetd.
import Quickshell
import Quickshell.Services.Greetd
import QtQuick

Item {
    id: root

    readonly property bool socketReady: Greetd.available
    property string failText: ""
    property bool busy: false
    property string _pendingPassword: ""

    function login(user: string, password: string) {
        const u = String(user || "").trim();
        const p = String(password || "");
        if (!u.length || !p.length)
            return;
        root.failText = "";
        if (!Greetd.available) {
            root.busy = false;
            root.failText = "unavailable";
            return;
        }
        root.busy = true;
        root._pendingPassword = p;
        Greetd.createSession(u);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(root._pendingPassword);
            root._pendingPassword = "";
            if (error && message)
                root.failText = String(message);
        }

        function onAuthFailure(message) {
            root.busy = false;
            root.failText = String(message || "failed");
        }

        function onReadyToLaunch() {
            Greetd.launch(["/usr/bin/start-hyprland"], ["XDG_SESSION_TYPE=wayland"], true);
        }

        function onError(err) {
            root.busy = false;
            root.failText = String(err || "");
        }
    }
}
