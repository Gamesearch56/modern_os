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
    property bool _applyMime: false
    property bool _restoreMime: false
    property string _lastPath: ""
    property var _lastValue
    property var _queue: []
    property var _follow: []
    property bool _drain: false
    readonly property bool pending: writeSoon.running || proc.running || restoreProc.running
        || chromeDebounce.running || followProc.running
        || ((root._queue || []).length > 0) || ((root._follow || []).length > 0)

    signal finished(bool ok)

    function _hyprPath(path: string): bool {
        const roots = ["input", "keybinds", "windows", "windowRules", "design", "monitors", "gaming"];
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

    function _mimePath(path: string): bool {
        return path === "apps.defaults"
            || path.indexOf("apps.defaults.videoPlayer") === 0
            || path.indexOf("apps.defaults.imageViewer") === 0
            || path.indexOf("apps.defaults.fileManager") === 0
            || path.indexOf("apps.defaults.mail") === 0;
    }

    function set(path, value) {
        try {
            const encoded = JSON.stringify(value);
            const next = [];
            const q = root._queue || [];
            let replaced = false;
            for (let i = 0; i < q.length; i++) {
                if (q[i].path === path) {
                    next.push({ path: path, encoded: encoded, value: value });
                    replaced = true;
                } else {
                    next.push(q[i]);
                }
            }
            if (!replaced)
                next.push({ path: path, encoded: encoded, value: value });
            root._queue = next;
            writeSoon.restart();
            Logger.debug("ConfigWrite", path + " = " + encoded);
        } catch (e) {
            root.lastError = String(e);
            Logger.error("ConfigWrite", String(e));
        }
    }

    function flush() {
        writeSoon.stop();
        root._drain = true;
        root._kick();
    }

    function _kick() {
        // Do not SIGTERM an in-flight write: slider drags used to kill
        // `mv` mid-rename (exit 15) and toast a Shell error.
        if (proc.running)
            return;
        const q = root._queue || [];
        if (q.length === 0)
            return;
        const job = q[0];
        root._queue = q.slice(1);
        root._lastPath = job.path;
        root._lastValue = job.value;
        root._patchChrome = root._chromePath(job.path);
        root._applyMime = root._mimePath(job.path);
        root._reloadHypr = job.path === "monitors" || job.path.indexOf("monitors.") === 0
            || job.path === "windows.titlebar" || job.path === "windowRules"
            || job.path === "motion.scale" || job.path === "motion"
            || job.path === "gaming" || job.path.indexOf("gaming.") === 0;
        proc.command = [Paths.modern, "config", "set", job.path, job.encoded];
        proc.running = true;
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
        root._restoreMime = false;
        const cmd = [Paths.modern, "config", "restore"];
        for (let i = 0; i < list.length; i++) {
            const p = String(list[i]);
            cmd.push(p);
            if (root._hyprPath(p))
                root._restoreReloadHypr = true;
            if (root._chromePath(p) || p === "design")
                root._restoreChrome = true;
            if (root._cursorPath(p))
                root._restoreCursor = true;
            if (root._mimePath(p))
                root._restoreMime = true;
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
            if (exitCode === 0) {
                Hypr.syncAppearance(root._lastPath, root._lastValue);
                if (root._reloadHypr)
                    root._enqueueFollow(["hyprctl", "reload"]);
                if (root._patchChrome)
                    chromeDebounce.restart();
                if (root._applyMime)
                    root._enqueueFollow([Paths.script("mime-defaults.sh")]);
            }
            root._afterWrite();
        }
    }

    function _enqueueFollow(cmd) {
        const key = (cmd || []).join("\t");
        const q = root._follow || [];
        for (let i = 0; i < q.length; i++) {
            if ((q[i] || []).join("\t") === key)
                return;
        }
        root._follow = q.concat([cmd]);
        root._kickFollow();
    }

    function _kickFollow() {
        if (followProc.running || proc.running || writeSoon.running
                || ((root._queue || []).length > 0))
            return;
        const q = root._follow || [];
        if (q.length === 0)
            return;
        followProc.command = q[0];
        root._follow = q.slice(1);
        followProc.running = true;
    }

    function _afterWrite() {
        if ((root._queue || []).length === 0) {
            root._drain = false;
            root._kickFollow();
            return;
        }
        if (root._drain)
            root._kick();
        else
            writeSoon.restart();
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
                root._enqueueFollow(["hyprctl", "reload"]);
            if (exitCode === 0 && root._restoreChrome)
                chromeDebounce.restart();
            if (exitCode === 0 && root._restoreCursor)
                Hypr.setCursor(Config.design.cursorTheme ?? "", Config.design.cursorSize ?? 24);
            if (exitCode === 0 && root._restoreMime)
                root._enqueueFollow([Paths.script("mime-defaults.sh")]);
            root.finished(exitCode === 0);
            root._kickFollow();
        }
    }

    Timer {
        id: writeSoon
        interval: Motion.configWriteMs
        repeat: false
        onTriggered: root._kick()
    }

    Timer {
        id: chromeDebounce
        interval: Math.max(Motion.mediumMs, 1)
        repeat: false
        onTriggered: root._enqueueFollow([
            Paths.script("theme-apply.sh"),
            "--chrome-only"
        ])
    }

    Process {
        id: followProc
        onExited: root._kickFollow()
    }
}
