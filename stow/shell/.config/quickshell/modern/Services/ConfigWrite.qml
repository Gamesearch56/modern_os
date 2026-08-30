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
    property bool _patchChrome: false
    property bool _restoreChrome: false
    property bool _restoreCursor: false
    property string _lastPath: ""
    property var _lastValue

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

    function _chromePath(path: string): bool {
        if (path === "typography" || path.indexOf("typography.") === 0)
            return true;
        if (path === "motion" || path.indexOf("motion.") === 0)
            return true;
        const keys = [
            "design.cornerRounding", "design.transparency",
            "design.cursorTheme", "design.cursorSize", "design.iconTheme"
        ];
        for (let i = 0; i < keys.length; i++) {
            if (path === keys[i])
                return true;
        }
        return false;
    }

    function _cursorPath(path: string): bool {
        return path === "design" || path === "design.cursorTheme"
            || path === "design.cursorSize";
    }

    function set(path, value) {
        try {
            const encoded = JSON.stringify(value);
            root._lastPath = path;
            root._lastValue = value;
            root._patchChrome = root._chromePath(path);
            root._reloadHypr = path === "monitors" || path.indexOf("monitors.") === 0
                || path === "windows.titlebar" || path === "windowRules"
                || path === "motion.scale" || path === "motion";
            proc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "config", "set", path, encoded];
            proc.running = false;
            Qt.callLater(() => {
                proc.running = true;
            });
            Logger.debug("ConfigWrite", path + " = " + encoded);
        } catch (e) {
            root.lastError = String(e);
            Logger.error("ConfigWrite", String(e));
        }
    }

    function patchMonitor(description, patch) {
        let m = { profiles: {}, rules: [], workspaceMode: "dynamic" };
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
        root._restoreChrome = false;
        root._restoreCursor = false;
        const cmd = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "config", "restore"];
        for (let i = 0; i < list.length; i++) {
            const p = String(list[i]);
            cmd.push(p);
            if (root._hyprPath(p))
                root._restoreReloadHypr = true;
            if (root._chromePath(p) || p === "design")
                root._restoreChrome = true;
            if (root._cursorPath(p))
                root._restoreCursor = true;
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
            if (exitCode !== 0)
                return;
            Hypr.syncAppearance(root._lastPath, root._lastValue);
            if (root._reloadHypr)
                Quickshell.execDetached(["hyprctl", "reload"]);
            if (root._patchChrome)
                chromeDebounce.restart();
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
            if (exitCode === 0 && root._restoreChrome)
                chromeDebounce.restart();
            if (exitCode === 0 && root._restoreCursor)
                Hypr.setCursor(Config.design.cursorTheme ?? "", Config.design.cursorSize ?? 24);
            root.finished(exitCode === 0);
        }
    }

    Timer {
        id: chromeDebounce
        interval: Math.max(Motion.mediumMs, 1)
        repeat: false
        onTriggered: Quickshell.execDetached([
            Quickshell.env("HOME") + "/modern_dotfile/scripts/theme-apply.sh",
            "--chrome-only"
        ])
    }
}
