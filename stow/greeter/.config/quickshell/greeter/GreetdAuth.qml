// Greetd lives only in this package. Importing it in the desktop
// tree would fail hosts that never installed greetd.
import Quickshell
import Quickshell.Services.Greetd
import QtQuick

Item {
    id: root

    property string username: ""
    property string failText: ""
    property bool busy: false

    function login(user: string, password: string) {
        const u = String(user || "").trim();
        const p = String(password || "");
        if (!u.length || !p.length)
            return;
        root.failText = "";
        root.busy = true;
        root._pendingPassword = p;
        Greetd.createSession(u);
    }

    property string _pendingPassword: ""

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(root._pendingPassword);
            root._pendingPassword = "";
        }

        function onAuthFailure(message) {
            root.busy = false;
            root.failText = message || "Authentication failed";
        }

        function onReadyToLaunch() {
            // Stay busy so the form keeps "Signing in…" until this
            // greeter compositor is replaced by the user session.
            Greetd.launch(["/usr/bin/start-hyprland"], ["XDG_SESSION_TYPE=wayland"], true);
        }

        function onError(err) {
            root.busy = false;
            root.failText = String(err || "");
        }
    }
}
