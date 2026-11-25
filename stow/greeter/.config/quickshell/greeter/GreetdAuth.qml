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
    property bool launched: false
    property string username: ""
    property string password: ""
    property string rememberedUser: ""
    property bool defaultReady: false
    property string _pendingPassword: ""
    property bool _answered: false
    property var _events: []

    function login() {
        const u = String(root.username || "").trim();
        const p = String(root.password || "");
        if (!u.length || !p.length)
            return;
        root.failText = "";
        if (!Greetd.available) {
            root._trace({ event: "unavailable" });
            root.busy = false;
            root.failText = "failed";
            return;
        }
        root.busy = true;
        root._answered = false;
        root._pendingPassword = p;
        root._trace({ event: "createSession" });
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
        Greetd.launch(["/usr/lib/modern/desktop-session.sh"], ["XDG_SESSION_TYPE=wayland"], true);
    }

    function _fail() {
        root.busy = false;
        root.launching = false;
        root.failText = "failed";
        root.password = "";
        root._pendingPassword = "";
    }

    // The last events of this greeter run, for bug reports. Never the
    // password or anything derived from it (length included).
    function _trace(info: var) {
        info.at = new Date().toISOString();
        root._events = root._events.concat([info]).slice(-20);
        try {
            trace.setText(JSON.stringify(root._events) + "\n");
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
                echoResponse: !!echoResponse
            });
            if (!responseRequired)
                return;
            // One password, one answer. A second prompt (expired password,
            // one-time code) must not receive the password again.
            if (root._answered) {
                root._trace({ event: "unsupportedPrompt" });
                Greetd.cancelSession();
                root._fail();
                return;
            }
            const secret = root._pendingPassword;
            root._pendingPassword = "";
            root._answered = true;
            Qt.callLater(() => Greetd.respond(secret));
        }

        function onAuthFailure(message) {
            root._trace({ event: "authFailure", message: String(message || "") });
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
            root.launched = true;
            root._trace({ event: "launched" });
            Quickshell.execDetached(["/usr/lib/modern/splash-hold.sh", "logout"]);
        }

        // After launch the socket closing is expected. Before it, a
        // failed start_session must give the form back, not spin forever.
        function onError(err) {
            root._trace({ event: "error", message: String(err || ""), launching: root.launching });
            if (root.launched)
                return;
            root._fail();
        }
    }
}
