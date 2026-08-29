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
    property string _pendingSlug: ""

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
                    if (root._pendingSlug.length > 0)
                        root.apply("", root._pendingSlug);
                    root._pendingSlug = "";
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
            Logger.error("Theme", I18n.t("theme.invalidSlug"));
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
        root._pendingSlug = slug;
        writeProc.command = [Quickshell.env("HOME") + "/modern_dotfile/scripts/theme-create.sh", slug, body];
        writeProc.running = true;
        ConfigWrite.set("design.activeProfile", slug);
    }

    function apply(wallpaperPath: string, profile: string) {
        const cmd = [Quickshell.env("HOME") + "/modern_dotfile/scripts/theme-apply.sh"];
        if (profile && profile.length > 0) {
            cmd.push("--profile");
            cmd.push(profile);
        }
        if (wallpaperPath && wallpaperPath.length > 0) {
            cmd.push("--wallpaper");
            cmd.push(wallpaperPath);
        }
        root.lastError = "";
        applyProc.command = cmd;
        applyProc.running = true;
    }

    Process {
        id: applyProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    root.lastError = t;
            }
        }
        onExited: (code) => {
            if (code !== 0)
                Logger.error("Theme", root.lastError.length > 0 ? root.lastError : I18n.t("theme.applyFailed"));
        }
    }
}
