// Calendar events for the Date and time popup. Fetch I/O lives in
// calendar-fetch.sh so secrets never appear on a curl argv.
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
    property bool busy: false
    property string raw: ""
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property bool _userCommit: false

    signal loadFailed()

    readonly property string icsUrl: CalendarAccount.icsUrl
    readonly property bool connected: CalendarAccount.connected
    readonly property string todayYmd: Ics.ymd(DateTime.displayDate(new Date()))

    Process {
        id: fetchProc
        command: [Paths.script("calendar-fetch.sh")]
        running: false
        stdout: StdioCollector {
            id: fetchOut
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    Logger.warn("Calendar", "calendar fetch failed");
            }
        }
        onExited: (code) => {
            root._ingest(code === 0 ? fetchOut.text : "");
        }
    }

    onIcsUrlChanged: {
        if (root.watching)
            root.refresh();
    }
    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }
    onViewYearChanged: root._recompute()
    onViewMonthChanged: root._recompute()

    Connections {
        target: CalendarAccount
        function onConnectedChanged() {
            if (root.watching)
                root.refresh();
        }
    }

    function commitUrl(url: string) {
        CalendarAccount.saveIcs(url);
        root.connectNow();
    }

    function connectNow() {
        root._userCommit = true;
        root.refresh();
    }

    function refresh() {
        root.busy = true;
        if (!root.connected && root.icsUrl.length === 0) {
            root._ingest("");
            return;
        }
        fetchProc.running = false;
        Qt.callLater(() => {
            fetchProc.running = true;
        });
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
        const empty = !text || String(text).length === 0;
        if (root._userCommit) {
            root._userCommit = false;
            if (empty && (root.connected || root.icsUrl.length > 0))
                root.loadFailed();
        }
        root.raw = text || "";
        root.events = Ics.parse(root.raw);
        root._recompute();
        root.busy = false;
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
        root.todayEvents = Ics.instancesInRange(root.events, todayStart, todayEnd);
    }
}
