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
    property int extraLongMs: 600
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
            root.failText = "unavailable";
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
        Greetd.launch(["/usr/bin/start-hyprland"], ["XDG_SESSION_TYPE=wayland"], true);
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

    Timer {
        id: launchWait
        interval: root.extraLongMs > 0 ? root.extraLongMs : 1
        repeat: false
        onTriggered: root._launchSession()
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
            root.launching = false;
            root.failText = String(message || "failed");
            root.password = "";
        }

        function onReadyToLaunch() {
            root.rememberUser();
            root.launching = true;
            if (root.extraLongMs <= 0)
                root._launchSession();
            else
                launchWait.restart();
        }

        function onError(err) {
            root.busy = false;
            root.launching = false;
            root.failText = String(err || "");
        }
    }
}
