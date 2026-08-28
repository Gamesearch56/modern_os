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

    function set(path, value) {
        try {
            const encoded = JSON.stringify(value);
            proc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/modern", "config", "set", path, encoded];
            proc.running = true;
            Logger.info("ConfigWrite", path + " = " + encoded);
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
        }
    }
}
