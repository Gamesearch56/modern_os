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
    property var pendingSpec: null
    property string pendingSeed: ""
    property bool extractNext: false
    property var _queuedApply: null
    property real _tintOverride: -1

    readonly property bool busy: applyProc.running || writeProc.running || root._queuedApply !== null

    signal created(string path)

    ThemeSpec { id: spec }

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
        onRunningChanged: root._armThemeWatch(running)
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

    Timer {
        id: themeWatch
        interval: Motion.followWatchMs
        repeat: false
        onTriggered: root._abortTheme()
    }

    function _armThemeWatch(on: bool) {
        if (on || applyProc.running || writeProc.running)
            themeWatch.restart();
        else
            themeWatch.stop();
    }

    function _abortTheme() {
        let hit = false;
        if (applyProc.running) {
            applyProc.running = false;
            hit = true;
        }
        if (writeProc.running) {
            writeProc.running = false;
            hit = true;
        }
        const hadQueue = root._queuedApply !== null;
        root._queuedApply = null;
        root._pendingSlug = "";
        if (!hit && !hadQueue)
            return;
        root.lastError = I18n.t("theme.applyFailed");
        Logger.warn("Theme", "apply timed out");
    }

    function refresh() { listProc.running = true; }
    function slugFor(s) { return spec.slugFor(s); }
    function findSlug(s) { return spec.findSlug(root.profiles, s); }
    function _norm(p) { return spec.norm(p); }

    function selectSpec(profileSpec) {
        let slug = root.findSlug(profileSpec);
        const exists = slug.length > 0;
        if (!exists)
            slug = root.slugFor(profileSpec);
        root.pendingSlug = slug;
        root.pendingSpec = spec.norm(profileSpec);
        if (!exists) {
            const body = JSON.stringify(spec.norm(profileSpec));
            root.lastError = "";
            root._pendingSlug = "";
            writeProc.command = [
                Paths.script("theme-create.sh"),
                slug, body, root.stateDir
            ];
            writeProc.running = true;
        }
        ConfigWrite.set("design.activeProfile", slug);
        const locked = root.pendingSeed || String(Config.design.sourceSeed || "");
        if (root.extractNext && !locked) {
            root._runApply("", slug, true, "", true);
            return;
        }
        const seed = locked || String(Colors.sourceColor || "");
        root._runApply("", slug, true, seed, false);
    }

    function create(name: string) {
        const slug = String(name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        if (!/^[a-z0-9-]+$/.test(slug)) {
            Logger.error("Theme", I18n.t("theme.invalidSlug"));
            return;
        }
        const body = JSON.stringify({
            variant: "tonal-spot", mode: "dark", contrast: "standard",
            sourceMode: "wallpaper", fixedSeed: null
        });
        root.lastError = "";
        root._pendingSlug = slug;
        writeProc.command = [Paths.script("theme-create.sh"), slug, body];
        writeProc.running = true;
        ConfigWrite.set("design.activeProfile", slug);
    }

    function apply(wallpaperPath: string, profile: string) {
        const p = profile || root.pendingSlug || String(Config.design.activeProfile || "");
        if (root.extractNext) {
            root._runApply(wallpaperPath, p, false, "", true);
            return;
        }
        const seed = root.pendingSeed || String(Config.design.sourceSeed || "");
        root._runApply(wallpaperPath, p, false, seed, false);
    }

    function applyShown(wallpaperPath: string) {
        const p = root.pendingSlug || String(Config.design.activeProfile || "");
        root.pendingSeed = "";
        root.extractNext = true;
        ConfigWrite.set("design.sourceSeed", "");
        root._runApply(wallpaperPath, p, true, "", true);
    }

    function applySeed(seed: string) {
        const hex = String(seed || "");
        if (!hex.length)
            return;
        root.pendingSeed = hex;
        root.extractNext = false;
        ConfigWrite.set("design.sourceSeed", hex);
        const p = root.pendingSlug || String(Config.design.activeProfile || "");
        root._runApply("", p, true, hex, false);
    }

    function applyTint(tint: real) {
        const p = root.pendingSlug || String(Config.design.activeProfile || "");
        const seed = root.pendingSeed || String(Config.design.sourceSeed || "");
        root._tintOverride = tint;
        root._runApply("", p, true, seed, false);
    }

    function _runApply(wallpaperPath: string, profile: string, skipWallpaper: bool, seed: string, extract: bool) {
        const job = {
            path: wallpaperPath || "", profile: profile || "",
            skip: !!skipWallpaper, seed: seed || "", extract: !!extract
        };
        if (applyProc.running) {
            root._queuedApply = job;
            return;
        }
        root._startApply(job);
    }

    function _startApply(job: var) {
        const cmd = [Paths.script("theme-apply.sh")];
        if (job.profile.length > 0) {
            cmd.push("--profile");
            cmd.push(job.profile);
        }
        if (job.path.length > 0) {
            cmd.push("--wallpaper");
            cmd.push(job.path);
        }
        if (job.skip)
            cmd.push("--skip-wallpaper");
        if (job.extract)
            cmd.push("--extract");
        else if (job.seed && String(job.seed).length > 0) {
            cmd.push("--seed");
            cmd.push(String(job.seed));
        }
        const tint = root._tintOverride >= 0 ? root._tintOverride : Number(Config.design.surfaceTint ?? 0.7);
        root._tintOverride = -1;
        cmd.push("--surface-tint");
        cmd.push(String(tint));
        root.lastError = "";
        applyProc.command = cmd;
        applyProc.running = true;
    }

    Process {
        id: applyProc
        running: false
        onRunningChanged: root._armThemeWatch(running)
        stdout: StdioCollector {}
        stderr: StdioCollector { id: applyErr }
        onExited: (code) => {
            Colors.refresh();
            if (code === 0)
                root.extractNext = false;
            const next = root._queuedApply;
            root._queuedApply = null;
            if (code !== 0) {
                root.pendingSlug = "";
                root.pendingSpec = null;
                root.pendingSeed = "";
            }
            if (next) {
                Qt.callLater(() => root._startApply(next));
                return;
            }
            if (code === 0)
                return;
            const err = spec.plain(applyErr.text);
            root.lastError = err;
            Logger.error("Theme", err.length > 0 ? err : I18n.t("theme.applyFailed"));
        }
    }
}
