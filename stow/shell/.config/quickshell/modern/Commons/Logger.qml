// Leveled logging + a small in-memory ring buffer for the future
// System > Diagnostics live-log view (docs/DECISIONS.md "diagnostics").
// Quickshell already persists every console.* call to its own
// per-session log.qslog on disk (printed at startup by `quickshell -p`),
// so this does not duplicate that with its own file I/O — the ring
// buffer is purely for in-process, no-disk-read display.
//
// Usage: Logger.info("Bar", "workspace changed"); Logger.error("Audio", "pipewire socket closed")
pragma Singleton

import Quickshell

Singleton {
    id: root

    readonly property var _levels: ({ debug: 0, info: 1, warn: 2, error: 3 })

    // "debug" | "info" | "warn" | "error" — raise to "warn" on a
    // low-power machine to cut console-log overhead. Not yet exposed in
    // config.json; wire to Settings > System once the Diagnostics section
    // (id: diagnostics) lands.
    property string level: "info"

    readonly property int maxHistory: 200
    property var history: []

    function _shouldLog(levelName: string): bool {
        return root._levels[levelName] >= root._levels[root.level];
    }

    function _record(levelName: string, tag: string, message: string) {
        root.history.push({ level: levelName, tag: tag, message: message, at: Date.now() });
        if (root.history.length > root.maxHistory)
            root.history.shift();
        root.history = root.history; // reassign to fire the change signal for bound views
    }

    function debug(tag: string, message: string) {
        if (!root._shouldLog("debug"))
            return;
        console.log(`[${tag}] ${message}`);
        root._record("debug", tag, message);
    }

    function info(tag: string, message: string) {
        if (!root._shouldLog("info"))
            return;
        console.log(`[${tag}] ${message}`);
        root._record("info", tag, message);
    }

    function warn(tag: string, message: string) {
        if (!root._shouldLog("warn"))
            return;
        console.warn(`[${tag}] ${message}`);
        root._record("warn", tag, message);
    }

    // Always logged — errors are never filtered by level.
    function error(tag: string, message: string) {
        console.error(`[${tag}] ${message}`);
        root._record("error", tag, message);
    }
}
