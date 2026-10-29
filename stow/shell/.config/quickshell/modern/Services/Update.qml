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
    property var _pacmanAll: []
    property var _pacmanSys: []
    property var _pacmanOther: []
    property string log: ""
    property string step: ""
    property bool open: false
    property real progress: -1
    property string error: ""
    property string _notified: ""
    property string _checkText: ""
    property bool _checkDone: false
    property bool _desktopDone: false
    property var desktop: ({ kind: "desktop", name: "", from: "", to: "", pending: false, reason: "", iconName: "", iconSource: Paths.brandLogo, subtitle: "" })
    signal finished(bool ok)
    signal notify(string summary, string body)

    readonly property bool indeterminate: root.running && root.progress < 0

    StoreClassify {
        id: shipped
        onShippedReadyChanged: {
            if (root._checkDone)
                root._parseCheck(root._checkText);
        }
    }

    UpdateClassify {
        id: classify
    }

    Process {
        id: checkProc
        command: ["checkupdates"]
        running: false
        stdout: StdioCollector { id: checkOut }
        onExited: (code) => {
            if (code !== 0 && code !== 2)
                root.error = I18n.t("settings.update.checkFailed");
            root._parseCheck(checkOut.text);
        }
    }

    Process {
        id: desktopProc
        command: [Paths.script("desktop-sync.sh"), "status"]
        running: false
        stdout: StdioCollector { id: desktopOut }
        onExited: () => {
            root._parseDesktop(desktopOut.text);
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
            root.notify(code === 0 ? I18n.t("settings.update.mirrorsDone") : I18n.t("settings.update.mirrorsFailed"), "");
            if (code === 0)
                root.refresh();
        }
    }

    // A desktop release ends with a shell reload that kills `proc`, so
    // its outcome arrives as a marker read once the reloaded shell starts.
    Process {
        id: noticeProc
        command: [Paths.modern, "update-notice"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const v = String(this.text || "").trim();
                if (v.length)
                    root.notify(I18n.t("settings.update.desktopApplied", ({ v: v })), I18n.t("settings.update.desktopAppliedBody"));
            }
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
        root._checkDone = false;
        root._desktopDone = false;
        desktopProc.running = true;
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

    function openChangelog(pkg) {
        const kind = String(pkg && pkg.kind || "pkg");
        const name = String(pkg && pkg.name || "");
        const from = String(pkg && pkg.from || "");
        const to = String(pkg && pkg.to || "");
        if (name.length === 0)
            return;
        if (kind !== "desktop" && to.length === 0)
            return;
        Quickshell.execDetached([Paths.script("update-changelog.sh"), kind, name, from, to]);
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

    function _parseCheck(text: string) {
        root._checkText = text;
        const parsed = classify.parseCheck(text, shipped.shipped);
        root._pacmanAll = parsed.all;
        root._pacmanSys = parsed.sys;
        root._pacmanOther = parsed.other;
        root._markCheckDone();
    }

    function _parseDesktop(text: string) {
        root.desktop = classify.parseDesktop(text);
        root._markDesktopDone();
    }

    function _markCheckDone() {
        root._checkDone = true;
        root._tryRebuild();
    }

    function _markDesktopDone() {
        root._desktopDone = true;
        root._tryRebuild();
    }

    function _tryRebuild() {
        if (!root._checkDone || !root._desktopDone)
            return;
        root.checking = false;
        root._rebuildLists();
    }

    function _rebuildLists() {
        const lists = classify.rebuild(root.desktop, root._pacmanAll, root._pacmanSys, root._pacmanOther);
        root.systemPkgs = lists.systemPkgs;
        root.otherPkgs = lists.otherPkgs;
        root.pending = lists.pending;
        const key = lists.pending.map(p => p.name).join(" ");
        if (lists.pending.length > 0 && key !== root._notified) {
            root._notified = key;
            root.notify(I18n.t("settings.update.available", ({ n: String(lists.pending.length) })), "");
        }
        if (lists.pending.length === 0)
            root._notified = "";
    }
}
