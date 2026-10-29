// PAM verifier for the lock overlay. Fail closed: a missing stack or
// a start() error never unlocks. Empty input is rejected before PAM
// (Arch system-auth has nullok).
import Quickshell
import Quickshell.Services.Pam
import QtQuick
import "../Commons"

Item {
    id: root

    property var host: null
    readonly property bool busy: pam.active

    property string _secret: ""

    function authenticate(password: string) {
        const secret = String(password || "");
        if (!secret.length) {
            root._fail();
            return;
        }
        if (!root.host)
            return;
        root.host.lastError = "";
        root._secret = secret;
        if (pam.active)
            pam.abort();
        if (!pam.start()) {
            root._secret = "";
            root._fail();
        }
    }

    function abort() {
        root._secret = "";
        if (pam.active)
            pam.abort();
    }

    function _fail() {
        root._secret = "";
        if (root.host) {
            root.host.lastError = "failed";
            root.host.password = "";
        }
        Logger.info("Session", "unlock refused");
    }

    function _ok() {
        root._secret = "";
        if (root.host)
            root.host.unlock();
    }

    PamContext {
        id: pam
        // system-auth has faillock and no pam_nologin, so an existing
        // session can still unlock when /etc/nologin is present.
        config: "system-auth"
        user: Quickshell.env("USER") || ""

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            const secret = root._secret;
            root._secret = "";
            respond(secret);
        }

        onCompleted: (result) => {
            if (result === PamResult.Success)
                root._ok();
            else
                root._fail();
        }

        onError: root._fail()
    }
}
