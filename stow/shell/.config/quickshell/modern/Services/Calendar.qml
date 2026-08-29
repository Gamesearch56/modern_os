// ICS calendar. Local path via FileView; http(s) via curl when the
// popup asks. Parsing lives in ics.js so this file stays the I/O owner.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"
import "ics.js" as Ics

Singleton {
    id: root

    property var events: []
    property var todayEvents: []
    property var eventDays: ({})
    property bool watching: false
    property string raw: ""
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property string home: Quickshell.env("HOME")
    readonly property string icsUrl: {
        const u = Config.accounts?.calendarIcsUrl;
        return typeof u === "string" ? u.trim() : "";
    }
    readonly property bool _http: root.icsUrl.indexOf("http://") === 0 || root.icsUrl.indexOf("https://") === 0
    readonly property string _filePath: {
        if (root._http || root.icsUrl.length === 0)
            return "";
        if (root.icsUrl.indexOf("~/") === 0)
            return root.home + root.icsUrl.slice(1);
        return root.icsUrl;
    }
    readonly property string todayYmd: Ics.ymd(new Date())

    FileView {
        id: icsFile
        path: root._filePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._ingest(text())
        onLoadFailed: {
            if (root._filePath.length > 0)
                Logger.warn("Calendar", "failed to load ICS file");
            if (!root._http)
                root._ingest("");
        }
    }

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            id: fetchOut
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    Logger.warn("Calendar", "ICS fetch failed");
            }
        }
        onExited: (code) => {
            root._ingest(code === 0 ? fetchOut.text : "");
        }
    }

    onIcsUrlChanged: root.refresh()
    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }
    onViewYearChanged: root._recompute()
    onViewMonthChanged: root._recompute()

    function refresh() {
        if (root._http) {
            fetchProc.running = false;
            fetchProc.command = ["curl", "-fsSL", "--max-time", "20", root.icsUrl];
            Qt.callLater(() => {
                fetchProc.running = true;
            });
            return;
        }
        if (root._filePath.length > 0)
            icsFile.reload();
        else
            root._ingest("");
    }

    function shiftMonth(delta: int) {
        let m = root.viewMonth + delta;
        let y = root.viewYear;
        while (m < 0) {
            m += 12;
            y--;
        }
        while (m > 11) {
            m -= 12;
            y++;
        }
        root.viewYear = y;
        root.viewMonth = m;
    }

    function resetView() {
        const n = new Date();
        root.viewYear = n.getFullYear();
        root.viewMonth = n.getMonth();
    }

    function hasEventsOn(ymd: string): bool {
        void root.eventDays;
        return !!root.eventDays[ymd];
    }

    function _ingest(text: string) {
        root.raw = text || "";
        root.events = Ics.parse(root.raw);
        root._recompute();
    }

    function _recompute() {
        const y = root.viewYear;
        const m = root.viewMonth;
        const start = new Date(y, m, 1);
        const end = new Date(y, m + 1, 1);
        const monthInst = Ics.instancesInRange(root.events, start, end);
        const days = {};
        for (let i = 0; i < monthInst.length; i++)
            days[monthInst[i].ymd] = true;
        root.eventDays = days;
        const now = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const todayEnd = new Date(todayStart.getTime() + 86400000);
        const today = Ics.instancesInRange(root.events, todayStart, todayEnd);
        for (let i = 0; i < today.length; i++) {
            if (!today[i].allDay && today[i].start)
                today[i].when = DateTime.formatTime(today[i].start, Config.language.timeFormat || "HH:mm", false);
        }
        root.todayEvents = today;
    }
}
