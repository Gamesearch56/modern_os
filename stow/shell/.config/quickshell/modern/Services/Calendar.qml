// Calendar events for the Date and time popup. Fetch I/O lives in
// calendar-fetch.sh so secrets never appear on an argv: a saved
// calendar is read from secrets.json, one being connected travels in the
// check process's environment and is saved only once it loads.
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
    // Last refresh or check failure as a translation key; "" when fine.
    property string errorKey: ""
    property bool checking: false
    property var _pending: null

    signal checked(bool ok)

    readonly property string icsUrl: CalendarAccount.icsUrl
    readonly property bool connected: CalendarAccount.connected
    readonly property string todayYmd: Ics.ymd(DateTime.displayDate(new Date()))
    readonly property int monthEventDays: Object.keys(root.eventDays).length

    Process {
        id: fetchProc
        command: [Paths.script("calendar-fetch.sh")]
        running: false
        stdout: StdioCollector {
            id: fetchOut
        }
        onExited: (code) => {
            if (code === 0) {
                root.errorKey = "";
                root._ingest(fetchOut.text);
            } else {
                Logger.warn("Calendar", "calendar fetch failed (" + code + ")");
                root.errorKey = root._errorKey(code, CalendarAccount.provider);
                root.busy = false;
            }
        }
    }

    Process {
        id: checkProc
        command: [Paths.script("calendar-fetch.sh")]
        running: false
        stdout: StdioCollector {
            id: checkOut
        }
        onExited: (code) => root._checkDone(code)
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

    function _errorKey(code: int, provider: string): string {
        if (code === 10)
            return provider === "apple" && CalendarAccount.usesAppleId ? "calendar.errorAppleAuth" : "calendar.errorLinkAuth";
        if (code === 11)
            return "calendar.errorLink";
        if (code === 12)
            return "calendar.errorOffline";
        return "calendar.errorGeneric";
    }

    function clearError() {
        root.errorKey = "";
    }

    // Try a calendar before saving it. user/password are only for an
    // Apple ID; link providers pass the iCal link as url.
    function check(provider: string, url: string, user: string, password: string) {
        if (root.checking)
            return;
        root._pending = { provider: provider, url: String(url || "").trim(), user: String(user || "").trim(), password: String(password || "") };
        root.errorKey = "";
        root.checking = true;
        checkProc.environment = {
            MODERN_CAL_CHECK: "1",
            MODERN_CAL_PROVIDER: provider,
            MODERN_CAL_URL: root._pending.url,
            MODERN_CAL_USER: root._pending.user,
            MODERN_CAL_PASSWORD: root._pending.password
        };
        checkProc.running = true;
    }

    function _checkDone(code: int) {
        const p = root._pending || ({});
        const apple = p.provider === "apple" && String(p.password || "").length > 0;
        root._pending = null;
        checkProc.environment = {};
        root.checking = false;
        if (code !== 0) {
            root.errorKey = code === 10 && apple ? "calendar.errorAppleAuth" : root._errorKey(code, "");
            root.checked(false);
            return;
        }
        if (apple)
            CalendarAccount.saveApple(p.user, p.password);
        else
            CalendarAccount.saveIcs(p.url);
        ConfigWrite.set("widgets.clock.calendarProvider", p.provider);
        root.errorKey = "";
        root._ingest(checkOut.text);
        root.checked(true);
    }

    function refresh() {
        if (!root.connected) {
            root.errorKey = "";
            root._ingest("");
            return;
        }
        root.busy = true;
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
