// Session user identity for PowerMenu and Settings → Users.
// Face from ~/.face or ~/.face.icon; display name from GECOS / $USER.
// Never a hardcoded username.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string loginName: Quickshell.env("USER") || ""
    property string displayName: root.loginName
    property url faceUrl: ""
    property bool hasFace: false
    property bool faceBusy: false
    property string faceError: ""

    readonly property string home: Quickshell.env("HOME")

    FileView {
        id: faceFile
        path: root.home + "/.face"
        watchChanges: true
        printErrors: false
        onFileChanged: root._refreshFace()
        onLoaded: root._refreshFace()
        onLoadFailed: root._refreshFace()
    }

    FileView {
        id: iconFile
        path: root.home + "/.face.icon"
        watchChanges: true
        printErrors: false
        onFileChanged: root._refreshFace()
        onLoaded: root._refreshFace()
        onLoadFailed: root._refreshFace()
    }

    FileView {
        id: passwdFile
        path: "/etc/passwd"
        watchChanges: true
        printErrors: false
        onLoaded: root._parsePasswd(text())
        onLoadFailed: root.displayName = root.loginName
        onFileChanged: reload()
    }

    function chooseFace() {
        if (root.faceBusy)
            return;
        root._runFace([]);
    }

    function clearFace() {
        if (root.faceBusy)
            return;
        root._runFace(["clear"]);
    }

    function _runFace(args: var) {
        root.faceBusy = true;
        root.faceError = "";
        faceProc.command = [Paths.script("face-set.sh")].concat(args || []);
        faceProc.running = true;
    }

    function _refreshFace() {
        const face = root.home + "/.face";
        const icon = root.home + "/.face.icon";
        const path = faceFile.loaded ? face : (iconFile.loaded ? icon : "");
        root.hasFace = path.length > 0;
        const next = path.length ? ("file://" + path) : "";
        // Same path after a replace does not reload the circle.
        if (String(root.faceUrl) === next && next.length) {
            root.faceUrl = "";
            Qt.callLater(() => { root.faceUrl = next; });
            return;
        }
        root.faceUrl = next;
    }

    Process {
        id: faceProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector { id: faceErr }
        onExited: (code) => {
            root.faceBusy = false;
            if (code === 0 || code === 1) {
                if (code === 0)
                    root.faceError = "";
                return;
            }
            const err = String(faceErr.text || "").trim();
            Logger.error("User", err.length ? err : "face");
            root.faceError = code === 3
                ? "settings.users.faceChooser"
                : "settings.users.faceFailed";
        }
    }

    function _parsePasswd(raw: string) {
        const user = root.loginName;
        const lines = (raw || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(":");
            if (parts[0] !== user)
                continue;
            const gecos = (parts[4] || "").split(",")[0].trim();
            root.displayName = gecos.length > 0 ? gecos : user;
            return;
        }
        root.displayName = user;
    }
}
