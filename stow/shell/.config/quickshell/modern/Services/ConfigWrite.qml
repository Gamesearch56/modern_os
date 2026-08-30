// The only writer of ~/.config/modern/config.json from the shell.
// Commons/Config is read-only by design (docs/DECISIONS.md #3); Modules
// cannot spawn processes, so this Service shells out to `modern config
// set` (scripts/config-set.sh) which jq-merges a single dotted path.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string lastError: ""
    property bool _reloadHypr: false
    property bool _restoreReloadHypr: false

    signal finished(bool ok)

    function _hyprPath(path: string): bool {
        const roots = ["input", "keybinds", "windows", "windowRules", "design", "monitors"];
        for (let i = 0; i < roots.length; i++) {
            const r = roots[i];
            if (path === r || path.indexOf(r + ".") === 0)
                return true;
        }
        return false;
    }

    function set(path, value) {
        try {
            const encoded = JSON.stringify(value);
            root._reloadHypr = path === "monitors" || path.indexOf("monitors.") === 0;
            proc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "config", "set", path, encoded];
            proc.running = true;
            Logger.debug("ConfigWrite", path + " = " + encoded);
        } catch (e) {
            root.lastError = String(e);
            Logger.error("ConfigWrite", String(e));
        }
    }

    function patchMonitor(description, patch) {
        let m = { profiles: {}, rules: [], workspaceMode: "fixed" };
        try {
            m = JSON.parse(JSON.stringify(Config.monitors || m));
        } catch (e) {
            Logger.warn("ConfigWrite", String(e));
        }
        if (!m.profiles)
            m.profiles = {};
        m.profiles[description] = Object.assign({}, m.profiles[description] || {}, patch);
        root.set("monitors", m);
    }

    function restore(paths) {
        const list = paths || [];
        if (list.length === 0)
            return;
        root.lastError = "";
        root._restoreReloadHypr = false;
        const cmd = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "config", "restore"];
        for (let i = 0; i < list.length; i++) {
            const p = String(list[i]);
            cmd.push(p);
            if (root._hyprPath(p))
                root._restoreReloadHypr = true;
        }
        restoreProc.command = cmd;
        restoreProc.running = true;
        Logger.debug("ConfigWrite", "restore " + list.join(" "));
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.info("ConfigWrite", t);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0) {
                    root.lastError = t;
                    Logger.error("ConfigWrite", t);
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.lastError.length === 0)
                Logger.error("ConfigWrite", "modern config set exited " + exitCode);
            if (exitCode === 0 && root._reloadHypr)
                Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }

    Process {
        id: restoreProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.info("ConfigWrite", t);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0) {
                    root.lastError = t;
                    Logger.error("ConfigWrite", t);
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.lastError.length === 0)
                Logger.error("ConfigWrite", "modern config restore exited " + exitCode);
            if (exitCode === 0 && root._restoreReloadHypr)
                Quickshell.execDetached(["hyprctl", "reload"]);
            root.finished(exitCode === 0);
        }
    }
}
