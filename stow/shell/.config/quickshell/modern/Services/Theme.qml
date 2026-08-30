// Lists theme profiles, writes derived ones under XDG state, and runs
// theme-apply.sh. Settings never touches files directly.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var slugs: []
    property var profiles: []
    property string lastPath: ""
    property string lastError: ""
    property string _pendingSlug: ""
    property string pendingSlug: ""
    property var _queuedApply: null

    signal created(string path)

    readonly property string dir: Quickshell.env("HOME") + "/.config/modern/themes"
    readonly property string stateDir: {
        const env = Quickshell.env("XDG_STATE_HOME");
        const base = (env && env.length > 0) ? env : (Quickshell.env("HOME") + "/.local/state");
        return base + "/modern/themes";
    }

    Process {
        id: listProc
        command: ["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/modern/themes\"; seen=\"\"; for f in \"$HOME/.config/modern/themes\"/*.json \"$state\"/*.json; do [ -f \"$f\" ] || continue; slug=$(basename \"$f\" .json); case \" $seen \" in *\" $slug \"*) continue ;; esac; seen=\"$seen $slug\"; jq -c --arg slug \"$slug\" '{slug:$slug,variant,mode,contrast,sourceMode,fixedSeed}' \"$f\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(s => s.length > 0);
                const out = [];
                const names = [];
                for (let i = 0; i < lines.length; i++) {
                    try {
                        const p = JSON.parse(lines[i]);
                        out.push(p);
                        names.push(p.slug);
                    } catch (e) {
                    }
                }
                root.profiles = out;
                root.slugs = names;
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

    function _norm(p) {
        return {
            variant: String(p.variant || "tonal-spot"),
            mode: String(p.mode || "dark"),
            contrast: String(p.contrast || "standard"),
            sourceMode: String(p.sourceMode || "wallpaper"),
            fixedSeed: p.fixedSeed ?? null
        };
    }

    function slugFor(spec) {
        const s = root._norm(spec);
        let slug = s.variant + "-" + s.mode;
        if (s.contrast !== "standard")
            slug += "-" + s.contrast;
        if (s.sourceMode !== "wallpaper")
            slug += "-fixed";
        return slug.replace(/[^a-z0-9-]+/g, "-");
    }

    function _same(a, b) {
        const x = root._norm(a);
        const y = root._norm(b);
        return x.variant === y.variant && x.mode === y.mode && x.contrast === y.contrast
            && x.sourceMode === y.sourceMode && String(x.fixedSeed) === String(y.fixedSeed);
    }

    function findSlug(spec) {
        const list = root.profiles || [];
        for (let i = 0; i < list.length; i++) {
            if (root._same(list[i], spec))
                return String(list[i].slug || "");
        }
        return "";
    }

    function selectSpec(spec) {
        let slug = root.findSlug(spec);
        const exists = slug.length > 0;
        if (!exists)
            slug = root.slugFor(spec);
        root.pendingSlug = slug;
        if (exists) {
            ConfigWrite.set("design.activeProfile", slug);
            root.apply("", slug);
            return;
        }
        const body = JSON.stringify(root._norm(spec));
        root.lastError = "";
        root._pendingSlug = slug;
        writeProc.command = [
            Paths.script("theme-create.sh"),
            slug, body, root.stateDir
        ];
        writeProc.running = true;
        ConfigWrite.set("design.activeProfile", slug);
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
        writeProc.command = [Paths.script("theme-create.sh"), slug, body];
        writeProc.running = true;
        ConfigWrite.set("design.activeProfile", slug);
    }

    function apply(wallpaperPath: string, profile: string) {
        root._runApply(wallpaperPath, profile, false);
    }

    function applyShown(wallpaperPath: string) {
        root._runApply(wallpaperPath, "", true);
    }

    function _runApply(wallpaperPath: string, profile: string, skipWallpaper: bool) {
        const spec = {
            path: wallpaperPath || "",
            profile: profile || "",
            skip: !!skipWallpaper
        };
        if (applyProc.running) {
            root._queuedApply = spec;
            return;
        }
        root._startApply(spec);
    }

    function _startApply(spec: var) {
        const cmd = [Paths.script("theme-apply.sh")];
        if (spec.profile.length > 0) {
            cmd.push("--profile");
            cmd.push(spec.profile);
        }
        if (spec.path.length > 0) {
            cmd.push("--wallpaper");
            cmd.push(spec.path);
        }
        if (spec.skip)
            cmd.push("--skip-wallpaper");
        root.lastError = "";
        applyProc.command = cmd;
        applyProc.running = true;
    }

    Process {
        id: applyProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: applyErr
        }
        onExited: (code) => {
            Colors.refresh();
            const next = root._queuedApply;
            root._queuedApply = null;
            if (next) {
                Qt.callLater(() => root._startApply(next));
                return;
            }
            if (code === 0)
                return;
            const err = applyErr.text.trim();
            root.lastError = err;
            Logger.error("Theme", err.length > 0 ? err : I18n.t("theme.applyFailed"));
        }
    }
}
