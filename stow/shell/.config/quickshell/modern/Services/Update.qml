// checkupdates plus modern update/mirrors (pkexec when not a TTY).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property bool running: false
    property bool mirrorsRunning: false
    property bool checking: false
    property var pending: []
    property var systemPkgs: []
    property var otherPkgs: []
    property string log: ""
    property string step: ""
    property bool open: false
    property real progress: -1
    property string error: ""
    property string _notified: ""
    signal finished(bool ok)
    signal notify(string summary, string body)

    readonly property bool indeterminate: root.running && root.progress < 0

    Process {
        id: checkProc
        command: ["checkupdates"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseCheck(this.text)
        }
        onExited: (code) => {
            root.checking = false;
            if (code !== 0 && code !== 2)
                root.error = I18n.t("settings.update.checkFailed");
        }
    }

    Process {
        id: proc
        running: false
        stdout: SplitParser {
            onRead: line => root._append(line)
        }
        stderr: SplitParser {
            onRead: line => root._append(line)
        }
        onExited: (code) => root._done(code === 0)
    }

    Process {
        id: mirrorsProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const t = String(this.text || "").trim();
                if (t.length)
                    root.error = t;
            }
        }
        onExited: (code) => {
            root.mirrorsRunning = false;
            root._notify(code === 0 ? I18n.t("settings.update.mirrorsDone") : I18n.t("settings.update.mirrorsFailed"), "");
            if (code === 0)
                root.refresh();
        }
    }

    Timer {
        interval: 3600000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.running && !root.checking)
                root.refresh();
        }
    }

    Timer {
        id: closeTimer
        interval: Motion.extraLongMs
        onTriggered: root.close()
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }

    function refresh() {
        if (root.checking || root.running)
            return;
        root.checking = true;
        root.error = "";
        checkProc.running = true;
    }

    function start() {
        if (root.running || root.pending.length === 0)
            return;
        root.open = true;
        root.log = "";
        root.step = I18n.t("settings.updateStep");
        root.progress = -1;
        root.running = true;
        root.error = "";
        proc.command = [Paths.modern, "update"];
        proc.running = true;
    }

    function refreshMirrors() {
        if (root.mirrorsRunning || root.running)
            return;
        root.error = "";
        root.mirrorsRunning = true;
        mirrorsProc.command = [Paths.modern, "mirrors"];
        mirrorsProc.running = true;
    }

    function close() {
        if (root.running)
            return;
        root.open = false;
    }

    function _append(line: string) {
        const t = String(line || "").trim();
        if (t.length === 0)
            return;
        root.log += t + "\n";
        root.step = t;
        const m = t.match(/\((\d+)\/(\d+)\)/);
        if (m)
            root.progress = Number(m[1]) / Number(m[2]);
        else if (t.toLowerCase().indexOf("snapshot") !== -1)
            root.progress = 0.1;
    }

    function _done(ok: bool) {
        root.running = false;
        root.progress = ok ? 1 : -1;
        root.notify(ok ? I18n.t("settings.update.success") : I18n.t("settings.update.failed"), root.step);
        if (ok) {
            closeTimer.restart();
            root.refresh();
        }
    }

    function _icon(name: string): string {
        const n = String(name || "");
        if (n.indexOf("linux") === 0)
            return "cpu";
        if (n.indexOf("hypr") !== -1 || n.indexOf("quickshell") === 0)
            return "preferences-desktop-display";
        if (n === "dolphin")
            return "system-file-manager";
        if (n === "kitty")
            return "utilities-terminal";
        return n === "vivaldi" ? "web-browser" : "package-x-generic-symbolic";
    }

    function _stem(id: string): string {
        return String(id || "").replace(/\.desktop$/i, "").replace(/^org\.kde\./, "").replace(/-stable$/, "").toLowerCase();
    }

    function _isSystem(name: string): bool {
        const n = String(name || "");
        if (/^(linux|mesa|nvidia|wayland|wlroots)/.test(n) || n.indexOf("hypr") !== -1 || n.indexOf("quickshell") === 0)
            return true;
        const defs = Config.apps.defaults || {};
        const stems = [root._stem(defs.browser), root._stem(defs.fileManager), root._stem(defs.terminal)];
        for (let i = 0; i < stems.length; i++) {
            if (stems[i].length && (n === stems[i] || n.indexOf(stems[i] + "-") === 0))
                return true;
        }
        return "pipewire wireplumber systemd greetd grim slurp matugen pacman reflector bluez networkmanager polkit stow qt6-base qt6-declarative kitty dolphin vivaldi".split(" ").indexOf(n) !== -1;
    }

    function _parseCheck(text: string) {
        const all = [];
        const sys = [];
        const other = [];
        const lines = String(text || "").trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/);
            if (!m)
                continue;
            const row = { name: m[1], from: m[2], to: m[3], iconName: root._icon(m[1]) };
            all.push(row);
            if (root._isSystem(m[1]))
                sys.push(row);
            else
                other.push(row);
        }
        root.pending = all;
        root.systemPkgs = sys;
        root.otherPkgs = other;
        const key = all.map(p => p.name).join(" ");
        if (all.length > 0 && key !== root._notified) {
            root._notified = key;
            root.notify(I18n.t("settings.update.available", ({ n: String(all.length) })), "");
        }
        if (all.length === 0)
            root._notified = "";
    }
}
