pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

// Uninstalling an application dropped from the launcher grid onto the
// dock trash. Owns the package lookup (app-package.sh, read-only); the
// removal is the Store's own confirm dialog, progress and notification.
// Exposes the verdict for the application being dragged, so the trash
// can grey out before the drop.

Singleton {
    id: root

    property string checkedId: ""
    property string pkg: ""
    // "" while the lookup runs, then "ok", "notPackaged" or "system".
    property string verdict: ""
    property string _dropId: ""

    readonly property bool blocked: root.verdict.length > 0 && root.verdict !== "ok"

    Process {
        id: proc
        running: false
        property string forId: ""
        stdout: StdioCollector {
            onStreamFinished: root._answer(proc.forId, this.text)
        }
        onExited: (code) => {
            if (code !== 0)
                root._answer(proc.forId, "");
        }
    }

    function check(id: string) {
        const key = String(id || "");
        root._dropId = "";
        root.checkedId = key;
        root.pkg = "";
        root.verdict = "";
        if (!key.length || key.startsWith("shell:") || ModernApps.shortName(key).length) {
            root.verdict = "notPackaged";
            return;
        }
        if (proc.running)
            proc.running = false;
        proc.forId = key;
        proc.command = [Paths.script("app-package.sh"), key];
        proc.running = true;
    }

    function _answer(id: string, text: string) {
        if (id !== root.checkedId || root.verdict.length)
            return;
        let out = null;
        try {
            out = JSON.parse(String(text || "").trim());
        } catch (e) {
            Logger.warn("AppUninstall", "lookup failed for " + id);
        }
        const name = out && out.pkg ? String(out.pkg) : "";
        if (out && out.removable === true && name.length) {
            root.pkg = name;
            root.verdict = Passwd.canManage ? "ok" : "system";
        } else {
            root.verdict = out && out.why === "system" ? "system" : "notPackaged";
        }
        if (root._dropId === id)
            root._act(id);
    }

    // A drop can land before the lookup answers; it then acts on the answer.
    function drop(id: string) {
        const key = String(id || "");
        if (key !== root.checkedId)
            root.check(key);
        if (!root.verdict.length) {
            root._dropId = key;
            return;
        }
        root._act(key);
    }

    function _act(id: string) {
        root._dropId = "";
        const label = Dock.labelFor(id);
        if (root.verdict !== "ok") {
            Notifications.toast(I18n.t("launcher.uninstall.blocked", ({ name: label })), "", "");
            return;
        }
        if (Store.mutating.length > 0) {
            Notifications.toast(I18n.t("launcher.uninstall.busy"), "", "");
            return;
        }
        Launcher.hide();
        Store.showPackage(root.pkg);
        Store.requestRemove(root.pkg);
    }
}
