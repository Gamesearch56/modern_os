// Greetd lives only in this package. Importing it in the desktop
// tree would fail hosts that never installed greetd.
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Io
import QtQuick

Item {
    id: root

    readonly property bool socketReady: Greetd.available
    property string failText: ""
    property bool busy: false
    property bool launching: false
    property string username: ""
    property string password: ""
    property string rememberedUser: ""
    property bool defaultReady: false
    property string _pendingPassword: ""

    function login() {
        const u = String(root.username || "").trim();
        const p = String(root.password || "");
        if (!u.length || !p.length)
            return;
        root.failText = "";
        if (!Greetd.available) {
            root.busy = false;
            root.failText = "failed";
            return;
        }
        root.busy = true;
        root._pendingPassword = p;
        Greetd.createSession(u);
    }

    function rememberUser() {
        const u = String(root.username || "").trim();
        if (!u.length)
            return;
        try {
            lastUser.setText(u + "\n");
        } catch (e) {
            /* default-user may still be 0644 on an older apply */
        }
    }

    function _launchSession() {
        Greetd.launch(["/usr/bin/start-hyprland", "--no-nixgl"], ["XDG_SESSION_TYPE=wayland"], true);
    }

    function _fail() {
        root.busy = false;
        root.launching = false;
        root.failText = "failed";
        root.password = "";
        root._pendingPassword = "";
    }

    function _trace(info: var) {
        try {
            trace.setText(JSON.stringify(info) + "\n");
        } catch (e) {
            /* session dir may be read-only on a partial apply */
        }
    }

    FileView {
        id: lastUser
        path: "/var/lib/modern/session/default-user"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = String(text() || "").trim();
            root.rememberedUser = t;
            root.defaultReady = true;
            if (t.length && root.username.length === 0)
                root.username = t;
        }
        onLoadFailed: root.defaultReady = true
    }

    FileView {
        id: trace
        path: "/var/lib/modern/session/auth-trace.json"
        printErrors: false
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            root._trace({
                event: "authMessage",
                message: String(message || ""),
                error: !!error,
                responseRequired: !!responseRequired,
                echoResponse: !!echoResponse,
                pendingLen: String(root._pendingPassword || "").length,
                available: Greetd.available
            });
            if (!responseRequired)
                return;
            const secret = root._pendingPassword;
            Qt.callLater(() => Greetd.respond(secret));
        }

        function onAuthFailure(message) {
            root._trace({
                event: "authFailure",
                message: String(message || ""),
                pendingLen: String(root._pendingPassword || "").length
            });
            root._fail();
        }

        function onReadyToLaunch() {
            root._trace({ event: "readyToLaunch" });
            root._pendingPassword = "";
            root.rememberUser();
            root.launching = true;
            root._launchSession();
        }

        function onLaunched() {
            root._trace({ event: "launched" });
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
        }

        function onError(err) {
            root._trace({ event: "error", message: String(err || "") });
            if (root.launching)
                return;
            root._fail();
        }
    }
}
