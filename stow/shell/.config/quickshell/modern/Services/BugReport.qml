// Problem reports: drives scripts/bug-report.sh step by step for
// Modules/BugReport. Owns the draft (description, ticked screenshots and
// files), the capture/collect/send/export processes and the outbox,
// which goes out whenever the network comes back. Emits notify() for
// results the user should see after the window is gone.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var areas: ["display", "hyprland", "shell", "sound", "bluetooth", "network", "games", "updates", "lock", "apps", "other"]
    property bool open: false
    property string reportId: ""
    property int step: 0
    property bool capturing: false
    property bool collecting: false
    property bool sending: false
    property var shots: []
    property var files: []
    property string title: ""
    property string description: ""
    property var categories: []
    property string when: "now"
    property string repeat: ""
    property string result: ""
    property int issueNumber: 0
    property string exportPath: ""
    property bool ready: false
    property int queued: 0
    property bool _reopen: false
    property string _collectedFor: ""
    property bool _drainOnStatus: true
    signal notify(string summary, string body)

    readonly property bool canSend: root.title.trim().length > 0 && !root.sending && !root.collecting
    readonly property bool _online: Network.connected
    on_OnlineChanged: if (root._online && root.queued > 0) outboxProc.running = true

    Component.onCompleted: statusProc.running = true

    function _run(proc, args) {
        proc.command = [Paths.script("bug-report.sh")].concat(args);
        proc.running = true;
    }

    // Overlays (power menu, launcher) need a moment to fade before the
    // screenshots, or the report shows them instead of the problem.
    function show(category: string) {
        if (root.open || root.capturing)
            return;
        // A file opened from the review list closes the window. The next
        // open continues that draft on the same step instead of starting over.
        if (root.reportId.length && root.result !== "sent") {
            root.open = true;
            return;
        }
        root.reportId = "";
        root.step = 0;
        root.shots = [];
        root.files = [];
        root.title = "";
        root.description = "";
        root.categories = root.areas.indexOf(category) >= 0 ? [category] : [];
        root.when = "now";
        root.repeat = "";
        root.result = "";
        root.issueNumber = 0;
        root.exportPath = "";
        root._collectedFor = "";
        root.capturing = true;
        root._reopen = true;
        root._run(newProc, ["new"]);
    }

    function hide() {
        root.open = false;
    }

    function retake() {
        if (!root.reportId.length || root.capturing)
            return;
        root.capturing = true;
        root._reopen = true;
        root.open = false;
        captureDelay.restart();
    }

    function toggleCategory(id: string) {
        const list = root.categories.slice();
        const at = list.indexOf(id);
        if (at >= 0)
            list.splice(at, 1);
        else
            list.push(id);
        root.categories = list;
    }

    function _toggle(list, name: string): var {
        return list.map(f => f.name === name ? Object.assign({}, f, { include: !f.include }) : f);
    }
    function toggleShot(name: string) { root.shots = root._toggle(root.shots, name); }
    function toggleFile(name: string) { root.files = root._toggle(root.files, name); }

    function goTo(n: int) {
        root.step = Math.max(0, Math.min(3, n));
        if (root.step >= 2 && root._collectedFor !== root.when && !root.collecting) {
            root.collecting = true;
            root._collectedFor = root.when;
            root._run(collectProc, ["collect", root.reportId, root.when]);
        }
    }

    function view(path: string) {
        if (!String(path || "").length)
            return;
        Quickshell.execDetached(["xdg-open", path]);
        root.hide();
    }

    function _picked(list): var {
        return list.filter(f => f.include).map(f => f.name);
    }

    function send() {
        if (!root.canSend)
            return;
        const req = {
            title: root.title.trim(),
            description: root.description.trim(),
            categories: root.categories.length ? root.categories : ["other"],
            when: root.when,
            repeat: root.repeat,
            files: root._picked(root.files),
            shots: root._picked(root.shots)
        };
        root.sending = true;
        root.result = "";
        root._run(sendProc, ["send", root.reportId, JSON.stringify(req)]);
    }

    function exportReport() {
        if (root.reportId.length)
            root._run(exportProc, ["export", root.reportId]);
    }

    function _list(text: string, include: bool): var {
        try {
            return (JSON.parse(String(text || "[]")) || []).map(f => Object.assign({ include: include }, f));
        } catch (e) {
            return [];
        }
    }

    Timer {
        id: captureDelay
        interval: Motion.reportCaptureMs
        onTriggered: root._run(captureProc, ["capture", root.reportId])
    }

    Process {
        id: newProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.reportId = this.text.trim();
                if (root.reportId.length)
                    captureDelay.restart();
                else
                    root.capturing = false;
            }
        }
    }

    Process {
        id: captureProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.shots = root._list(this.text, Config.bugReport.screenshotsDefault);
                root.capturing = false;
                if (root._reopen)
                    root.open = true;
                root._reopen = false;
            }
        }
    }

    Process {
        id: collectProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = root._list(this.text, true);
                root.collecting = false;
            }
        }
    }

    Process {
        id: sendProc
        stdout: StdioCollector { id: sendOut }
        onExited: (code) => {
            root.sending = false;
            root.issueNumber = code === 0 ? Number(sendOut.text.trim()) || 0 : 0;
            root.result = ({ 0: "sent", 20: "queued", 21: "notSetUp", 22: "refused" })[code] || "failed";
            root.step = 3;
            statusProc.running = true;
        }
    }

    Process {
        id: exportProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.exportPath = this.text.trim();
                if (root.exportPath.length)
                    root.result = "exported";
            }
        }
    }

    Process {
        id: statusProc
        command: [Paths.script("bug-report.sh"), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(this.text || "{}");
                    root.ready = !!s.ready;
                    root.queued = Number(s.queued) || 0;
                } catch (e) {
                    root.ready = false;
                }
                if (root._drainOnStatus && root._online && root.queued > 0 && !outboxProc.running)
                    outboxProc.running = true;
                root._drainOnStatus = false;
            }
        }
    }

    Process {
        id: outboxProc
        command: [Paths.script("bug-report.sh"), "outbox"]
        stdout: SplitParser {
            onRead: line => {
                if (String(line).indexOf("sent ") === 0)
                    root.notify(I18n.t("bugReport.queuedSent"), "");
            }
        }
        onExited: statusProc.running = true
    }

    IpcHandler {
        target: "bugReport"
        function open(category: string) { root.show(category); }
        function close() { root.hide(); }
        function zzDebug(t: string, n: int) { root.title = t; if (n === 9) { root.goTo(3); root.send(); } else if (n === 8) root.exportReport(); else root.goTo(n); }
    }
}
