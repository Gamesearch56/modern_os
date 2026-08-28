// Writes ~/.config/modern/themes/<slug>.json. Settings never touches files.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var slugs: []
    property string lastPath: ""
    property string lastError: ""

    signal created(string path)

    readonly property string dir: Quickshell.env("HOME") + "/.config/modern/themes"

    Process {
        id: listProc
        command: ["sh", "-c", "ls -1 \"$HOME/.config/modern/themes\"/*.json 2>/dev/null | xargs -n1 basename | sed 's/\\.json$//'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(s => s.length > 0);
                root.slugs = lines;
            }
        }
    }

    Process {
        id: writeProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0) {
                    root.lastPath = t;
                    root.created(t);
                    listProc.running = true;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0) {
                    root.lastError = t;
                    Logger.error("Theme", t);
                }
            }
        }
    }

    function refresh() {
        listProc.running = true;
    }

    function create(name: string) {
        const slug = String(name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        if (!/^[a-z0-9-]+$/.test(slug)) {
            Logger.error("Theme", "invalid theme slug");
            return;
        }
        const body = JSON.stringify({
            variant: "tonal-spot",
            mode: "dark",
            contrast: "standard",
            sourceMode: "wallpaper",
            fixedSeed: null
        });
        root.lastError = "";
        writeProc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/theme-create.sh", slug, body];
        writeProc.running = true;
        ConfigWrite.set("design.activeProfile", slug);
    }
}
