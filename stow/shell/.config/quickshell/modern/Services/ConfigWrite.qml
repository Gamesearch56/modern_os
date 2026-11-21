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
    property bool _patchMonitors: false
    property bool _patchKeyboard: false
    property bool _patchSessionChrome: false
    property bool _restoreChrome: false
    property bool _restoreMonitors: false
    property bool _restoreKeyboard: false
    property bool _restoreSessionChrome: false
    property bool _restoreCursor: false
    property bool _applyMime: false
    property bool _restoreMime: false
    property string _lastPath: ""
    property var _lastValue
    property var _queue: []
    property bool _drain: false
    readonly property bool writing: proc.running || writeSoon.running
        || ((root._queue || []).length > 0)
    readonly property bool pending: writing || restoreProc.running || follow.busy

    signal finished(bool ok)

    ConfigWritePaths {
        id: paths
    }

    ConfigWriteFollow {
        id: follow
        writer: root
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
        root._patchChrome = paths.chromePath(job.path);
        root._applyMime = paths.mimePath(job.path);
        root._reloadHypr = job.path === "monitors" || job.path.indexOf("monitors.") === 0
            || job.path === "windowRules"
            || job.path === "motion.scale" || job.path === "motion"
            || job.path === "gaming" || job.path.indexOf("gaming.") === 0 || job.path === "input.mouseSideButtons";
        root._patchMonitors = job.path === "monitors" || job.path.indexOf("monitors.") === 0;
        root._patchKeyboard = job.path === "input" || job.path === "input.kbLayout"
            || job.path === "input.kbVariant";
        root._patchSessionChrome = job.path === "language" || job.path.indexOf("language.") === 0;
        proc.command = [Paths.modern, "config", "set", job.path, job.encoded];
        proc.running = true;
    }

    function patchMonitor(description, patch) {
        const one = {};
        one[description] = patch;
        root.patchMonitors(one);
    }

    // One write for several profiles: back-to-back patchMonitor calls
    // would each start from the not-yet-reloaded Config and drop the rest.
    function patchMonitors(patches) {
        let m = { profiles: {}, rules: [], workspaceMode: "dynamic" };
        try {
            m = JSON.parse(JSON.stringify(Config.monitors || m));
        } catch (e) {
            Logger.warn("ConfigWrite", String(e));
        }
        if (!m.profiles)
            m.profiles = {};
        for (const d in patches)
            m.profiles[d] = Object.assign({}, m.profiles[d] || {}, patches[d]);
        root.set("monitors", m);
    }

    function restore(list) {
        const items = list || [];
        if (items.length === 0)
            return;
        root.lastError = "";
        root._restoreReloadHypr = false;
        root._restoreChrome = false;
        root._restoreMonitors = false;
        root._restoreKeyboard = false;
        root._restoreSessionChrome = false;
        root._restoreCursor = false;
        root._restoreMime = false;
        const cmd = [Paths.modern, "config", "restore"];
        for (let i = 0; i < items.length; i++) {
            const p = String(items[i]);
            cmd.push(p);
            if (paths.hyprPath(p))
                root._restoreReloadHypr = true;
            if (p === "monitors" || p.indexOf("monitors.") === 0)
                root._restoreMonitors = true;
            if (p === "input" || p === "input.kbLayout" || p === "input.kbVariant")
                root._restoreKeyboard = true;
            if (p === "language" || p.indexOf("language.") === 0)
                root._restoreSessionChrome = true;
            if (paths.chromePath(p) || p === "design")
                root._restoreChrome = true;
            if (paths.cursorPath(p))
                root._restoreCursor = true;
            if (paths.mimePath(p))
                root._restoreMime = true;
        }
        restoreProc.command = cmd;
        restoreProc.running = true;
        Logger.debug("ConfigWrite", "restore " + items.join(" "));
    }

    function _afterWrite() {
        if ((root._queue || []).length === 0) {
            root._drain = false;
            follow.kick();
            return;
        }
        if (root._drain)
            root._kick();
        else
            writeSoon.restart();
    }

    Process {
        id: proc
        onRunningChanged: {
            if (running)
                writeWatch.restart();
            else if (!restoreProc.running)
                writeWatch.stop();
        }
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
                    follow.enqueue(["hyprctl", "reload"]);
                if (root._patchChrome)
                    follow.requestChrome();
                if (root._patchMonitors)
                    follow.enqueue([Paths.script("session-monitors-sync.sh")]);
                if (root._patchKeyboard)
                    follow.enqueue([Paths.script("session-keyboard-sync.sh")]);
                if (root._patchSessionChrome)
                    follow.enqueue([Paths.script("session-chrome-sync.sh")]);
                if (root._applyMime)
                    follow.enqueue([Paths.script("mime-defaults.sh")]);
            }
            root._afterWrite();
        }
    }

    Process {
        id: restoreProc
        onRunningChanged: {
            if (running)
                writeWatch.restart();
            else if (!proc.running)
                writeWatch.stop();
        }
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
                follow.enqueue(["hyprctl", "reload"]);
            if (exitCode === 0 && root._restoreMonitors)
                follow.enqueue([Paths.script("session-monitors-sync.sh")]);
            if (exitCode === 0 && root._restoreKeyboard)
                follow.enqueue([Paths.script("session-keyboard-sync.sh")]);
            if (exitCode === 0 && root._restoreSessionChrome)
                follow.enqueue([Paths.script("session-chrome-sync.sh")]);
            if (exitCode === 0 && root._restoreChrome)
                follow.requestChrome();
            if (exitCode === 0 && root._restoreCursor)
                Hypr.setCursor(Config.design.cursorTheme ?? "", Config.design.cursorSize ?? 24);
            if (exitCode === 0 && root._restoreMime)
                follow.enqueue([Paths.script("mime-defaults.sh")]);
            root.finished(exitCode === 0);
            follow.kick();
        }
    }

    Timer {
        id: writeSoon
        interval: Motion.configWriteMs
        repeat: false
        onTriggered: root._kick()
    }

    Timer {
        id: writeWatch
        interval: Motion.followWatchMs
        repeat: false
        onTriggered: {
            if (proc.running)
                proc.running = false;
            if (restoreProc.running)
                restoreProc.running = false;
            root._queue = [];
            root._drain = false;
            follow._abortHang();
            root.lastError = "config write timed out";
            Logger.warn("ConfigWrite", root.lastError);
        }
    }
}
