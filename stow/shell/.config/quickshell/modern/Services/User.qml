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
    property string _intent: ""
    property int _whichGen: 0

    readonly property string home: Quickshell.env("HOME")

    FileView {
        id: faceFile
        path: root.home + "/.face"
        watchChanges: true
        printErrors: false
        onFileChanged: root._which()
        onLoaded: root._which()
        onLoadFailed: root._which()
    }

    FileView {
        id: iconFile
        path: root.home + "/.face.icon"
        watchChanges: true
        printErrors: false
        onFileChanged: root._which()
        onLoaded: root._which()
        onLoadFailed: root._which()
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
        root._intent = "choose";
        root._runFace([]);
    }

    function clearFace() {
        if (root.faceBusy)
            return;
        root._intent = "clear";
        root._runFace(["clear"]);
    }

    function applyFace(path: string, rotate: string, crop: string) {
        if (root.faceBusy)
            return;
        root._intent = "apply";
        root._runFace(["--edit", path, rotate, crop]);
    }

    function _runFace(args: var) {
        root.faceBusy = true;
        root.faceError = "";
        faceProc.command = [Paths.script("face-set.sh")].concat(args || []);
        faceProc.running = false;
        faceProc.running = true;
    }

    // FileView.loaded stays true for a picture that was just removed, so the
    // circle kept the old path and never showed the file that replaced it.
    function _which() {
        root._whichGen += 1;
        whichProc.gen = root._whichGen;
        whichProc.command = [Paths.script("face-set.sh"), "--which"];
        whichProc.running = false;
        whichProc.running = true;
    }

    function _whichPath(text: string): string {
        const lines = String(text || "").split("\n");
        let last = "none";
        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "none" || lines[i].indexOf("have ") === 0)
                last = lines[i];
        }
        return last.indexOf("have ") === 0 ? last.slice(5) : "";
    }

    function _show(path: string) {
        const text = String(path || "").trim();
        root.hasFace = text.length > 0;
        const next = text.length ? ("file://" + text) : "";
        if (String(root.faceUrl) === next && next.length) {
            root.faceUrl = "";
            Qt.callLater(() => { root.faceUrl = next; });
            return;
        }
        root.faceUrl = next;
    }

    Component.onCompleted: root._which()

    Process {
        id: whichProc
        property int gen: 0
        running: false
        stdout: StdioCollector { id: whichOut }
        onExited: {
            if (gen !== root._whichGen)
                return;
            root._show(root._whichPath(whichOut.text));
        }
    }

    Process {
        id: faceProc
        running: false
        stdout: StdioCollector { id: faceOut }
        stderr: StdioCollector { id: faceErr }
        onExited: (code) => {
            const intent = root._intent;
            root._intent = "";
            if (code === 0 || code === 1) {
                if (code === 0) {
                    root.faceError = "";
                    const lines = String(faceOut.text || "").split("\n").filter(line => line.length > 0);
                    const printed = lines.length ? lines[lines.length - 1] : "";
                    root._show(intent === "clear" ? "" : printed);
                    if (intent === "apply")
                        Notifications.toast(I18n.t("settings.users.faceSaved"), "", printed);
                }
            } else {
                const err = String(faceErr.text || "").trim();
                Logger.error("User", err.length ? err : "face");
                root.faceError = code === 3
                    ? "settings.users.faceChooser"
                    : "settings.users.faceFailed";
            }
            root.faceBusy = false;
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
