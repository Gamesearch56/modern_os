// One pkexec pacman transaction at a time. Never kills an in-flight
// process — aborting pacman mid-transaction corrupts the local db.
import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Item {
    id: root

    property string pendingName: ""
    property string pendingAction: ""
    property string mutating: ""
    property string mutAction: ""
    // Kept after mutAction is cleared so a closing dialog still names
    // the action that just finished.
    property string doneAction: ""
    property string lastName: ""
    property string errorKey: ""
    property string log: ""
    property bool _userCancel: false
    readonly property bool busy: root.mutating.length > 0
    readonly property bool authWait: root.busy && String(root.log || "").trim().length === 0
    signal notify(string summary, string body)
    signal finished(bool ok)

    readonly property int _logMax: 32768

    Process {
        id: proc
        running: false
        stdout: SplitParser {
            onRead: line => root._append(line)
        }
        stderr: SplitParser {
            onRead: line => root._append(line)
        }
        onExited: (code) => root._done(code)
    }

    function requestInstall(name: string) { root._request(name, "install"); }
    function requestUpdate(name: string) { root._request(name, "update"); }
    function requestRemove(name: string) { root._request(name, "remove"); }

    function _request(name: string, action: string) {
        try {
            if (root.busy)
                return;
            if (!Passwd.canManage)
                return;
            if (!root.validName(name)) {
                Logger.warn("Store", "rejected package name");
                return;
            }
            root.pendingName = name;
            root.pendingAction = action;
            root.errorKey = "";
        } catch (e) {
            Logger.error("Store", String(e));
        }
    }

    function cancel() {
        try {
            if (root.busy && root.authWait) {
                root._userCancel = true;
                proc.running = false;
                return;
            }
            if (root.busy)
                return;
            root.pendingName = "";
            root.pendingAction = "";
        } catch (e) {
            Logger.error("Store", String(e));
        }
    }

    function confirm() {
        try {
            if (root.busy || proc.running)
                return;
            const name = root.pendingName;
            const action = root.pendingAction;
            root.pendingName = "";
            root.pendingAction = "";
            if (!root.validName(name) || (action !== "install" && action !== "remove" && action !== "update")) {
                Logger.warn("Store", "confirm rejected");
                return;
            }
            root.mutAction = action;
            root.mutating = name;
            root.lastName = name;
            root.errorKey = "";
            root.log = "";
            root._userCancel = false;
            Logger.info("Store", action + " " + name);
            proc.command = [Paths.script("pkg-mutate.sh"), action, name];
            proc.running = true;
        } catch (e) {
            root.mutating = "";
            root.mutAction = "";
            root.errorKey = "store.failed";
            Logger.warn("Store", String(e));
            try {
                root.notify(I18n.t("store.failed"), "");
            } catch (e2) {
            }
        }
    }

    function dismissError() {
        if (root.busy)
            return;
        root.errorKey = "";
        root.log = "";
        root.lastName = "";
    }

    function validName(name: string): bool {
        const n = String(name || "");
        if (n.length < 1 || n.length > 64)
            return false;
        return /^[a-z0-9][a-z0-9.+_-]*$/.test(n);
    }

    function _append(line: string) {
        try {
            const t = String(line || "").replace(/\r/g, "").trim();
            if (!t.length)
                return;
            let next = root.log + t + "\n";
            if (next.length > root._logMax)
                next = next.substring(next.length - root._logMax);
            root.log = next;
        } catch (e) {
            Logger.error("Store", String(e));
        }
    }

    function _done(code: int) {
        const name = root.mutating;
        const action = root.mutAction;
        root.doneAction = action;
        if (root._userCancel) {
            root._userCancel = false;
            code = 126;
        }
        const ok = code === 0;
        try {
            root.mutating = "";
            root.mutAction = "";
            if (ok) {
                Logger.info("Store", "done " + action + " " + name);
                const key = action === "remove" ? "store.doneRemove"
                    : (action === "update" ? "store.doneUpdate" : "store.doneInstall");
                root.notify(I18n.t(key, ({ name: name })), "");
                root.finished(true);
                return;
            }
            const key = root._errorKey(code);
            root.errorKey = key;
            if (root.log.trim().length === 0)
                root._append(I18n.t(key, ({ name: name })));
            Logger.warn("Store", action + " " + name + " exit " + String(code));
            root.notify(I18n.t(key, ({ name: name })), name);
            root.finished(false);
        } catch (e) {
            root.errorKey = "store.failed";
            Logger.error("Store", String(e));
            root.finished(false);
        }
    }

    function _errorKey(code: int): string {
        if (code === 2)
            return "store.invalid";
        if (code === 3)
            return "store.notFound";
        if (code === 4)
            return "store.notInstalled";
        if (code === 5)
            return "store.protected";
        if (code === 6)
            return "store.agentMissing";
        if (code === 126 || code === 127)
            return "store.cancelled";
        return "store.failed";
    }
}
