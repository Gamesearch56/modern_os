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
    readonly property bool mirrorsRunning: mirrors.running
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
    property bool _queued: false
    property var _omit: ({})
    property var _ran: []
    property int _gen: 0
    property int _hold: 0
    property double _checkedAt: 0
    property bool restarting: false
    property var desktop: ({ kind: "desktop", name: "", from: "", to: "", pending: false, reason: "", iconName: "", iconSource: Paths.brandLogo, subtitle: "" })
    signal finished(bool ok)
    signal notify(string summary, string body, string section)

    readonly property bool indeterminate: root.running && root.progress < 0

    StoreClassify {
        id: shipped
        onShippedReadyChanged: {
            if (root._checkDone)
                root._parseCheck(root._checkText);
        }
    }

    UpdateClassify { id: classify }
    UpdateProgress { id: meter }

    // A reload mid-update would restart this service; the finished update reloads once.
    Binding { target: Quickshell; property: "watchFiles"; value: false; when: root.running }

    Process {
        id: checkProc
        command: ["checkupdates"]
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
        stdout: StdioCollector { id: desktopOut }
        onExited: () => root._parseDesktop(desktopOut.text)
    }

    // update-run.sh owns the update; this only follows its log, so a
    // reload or crash of the shell cannot cut pacman off. On start it
    // re-attaches to an update that outlived the previous shell.
    Process {
        id: proc
        command: [Paths.script("update-run.sh"), "attach"]
        running: true
        stdout: SplitParser { onRead: line => root._append(line) }
        stderr: SplitParser { onRead: line => root._append(line) }
        onExited: (code) => root._done(code)
    }

    UpdateMirrors {
        id: mirrors
        onErrorChanged: if (mirrors.error.length) root.error = mirrors.error
        onFinished: (ok) => {
            root.notify(ok ? I18n.t("settings.update.mirrorsDone") : I18n.t("settings.update.mirrorsFailed"), "", "");
            if (ok)
                root.refresh(true);
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
                    root.notify(I18n.t("settings.update.desktopApplied", ({ v: v })), I18n.t("settings.update.desktopAppliedBody"), "");
            }
        }
    }

    Timer {
        interval: 3600000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: closeTimer
        interval: Motion.updateSettleMs
        onTriggered: root.close()
    }

    onWatchingChanged: if (root.watching) root.refresh()

    function drop(name: string) {
        const n = String(name || "");
        root.pending = (root.pending || []).filter(p => String(p && p.name || "") !== n);
        const omit = Object.assign({}, root._omit);
        omit[n] = true;
        root._omit = omit;
        root._hold = root._gen + 1;
        root.refresh(true);
    }

    function refresh(force: bool) {
        if (root.running)
            return;
        if (!force && root._checkedAt > 0 && Date.now() - root._checkedAt < Motion.updateCheckGapMs)
            return;
        if (root.checking) {
            if (force)
                root._queued = true;
            return;
        }
        root._checkedAt = Date.now();
        root._gen += 1;
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
        root._ran = root.pending;
        root.log = "";
        root.step = I18n.t("settings.updateStep");
        meter.reset();
        root.progress = -1;
        root.running = true;
        root.error = "";
        proc.command = [Paths.script("update-run.sh"), "start"];
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
        if (root.running)
            return;
        root.error = "";
        mirrors.start();
    }

    function close() {
        if (root.running)
            return;
        // Mark first. Closing the log can call back in before the reload starts.
        const go = root.restarting && root.progress >= 0;
        if (go)
            root.progress = -1;
        root.open = false;
        if (!go)
            return;
        closeTimer.stop();
        Quickshell.execDetached([Paths.script("update-run.sh"), "reload"]);
    }

    function _append(line: string) {
        const t = String(line || "").replace(/\u001b\[[0-9;]*m/g, "").split("\r").pop().trim();
        if (!t.length)
            return;
        if (!root.running) {
            root.open = true;
            root.running = true;
            root._ran = root.pending;
        }
        const marker = meter.feed(t);
        root.progress = meter.value;
        if (marker) { if (meter.stage === "finish") root.step = I18n.t("settings.update.finished"); return; }
        root.log += t + "\n";
        // The clock and INFO/OK stay in the log. The title is the message.
        const label = t.replace(/^\[[0-9:.T +-]+\]\s*/, "").replace(/^(?:INFO|OK|WARN|ERROR)\s+/, "").trim();
        if (label.length > 0)
            root.step = label;
    }

    // 75: no update to attach to. 3: a half-applied update was rolled back.
    function _done(code: int) {
        if (code === 75 && !root.running)
            return;
        const ok = code === 0;
        root.running = false;
        root.progress = ok ? 1 : -1;
        if (code === 3)
            root.notify(I18n.t("settings.update.rolledBack"), I18n.t("settings.update.rolledBackBody"), "");
        else if (!ok || classify.doneSummary(root._ran).length)
            root.notify(ok ? classify.doneSummary(root._ran) : classify.failureText(code), ok ? "" : root.step, "");
        if (ok) { root.restarting = (root._ran || []).filter(p => String(p && p.kind || "") === "desktop").length > 0; closeTimer.restart(); root.refresh(true); }
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

    function _markCheckDone() { root._checkDone = true; root._tryRebuild(); }
    function _markDesktopDone() { root._desktopDone = true; root._tryRebuild(); }

    function _tryRebuild() {
        if (!root._checkDone || !root._desktopDone)
            return;
        root.checking = false;
        root._rebuildLists();
        if (root._queued) {
            root._queued = false;
            root.refresh(true);
        }
    }

    function _rebuildLists() {
        const lists = classify.rebuild(root.desktop, root._pacmanAll, root._pacmanSys, root._pacmanOther);
        root.systemPkgs = lists.systemPkgs;
        root.otherPkgs = lists.otherPkgs;
        let pending = lists.pending;
        if (root._gen < root._hold) {
            const omit = root._omit;
            pending = pending.filter(p => !omit[String(p && p.name || "")]);
        } else {
            root._omit = ({});
            root._hold = 0;
        }
        root.pending = pending;
        const key = pending.map(p => p.name).join(" ");
        if (pending.length > 0 && key !== root._notified) {
            root._notified = key;
            root.notify(classify.availableNotice(pending), "", "system");
        }
        if (pending.length === 0)
            root._notified = "";
    }
}
