// Optional ICS calendar. FileView on Config.accounts.calendarIcsUrl
// when that value is a string path/URL. Parsing is a stub: events
// stays [] until a real ICS parser lands.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var events: []
    property string raw: ""

    readonly property string icsUrl: {
        const a = Config.accounts;
        const u = a?.calendarIcsUrl;
        return typeof u === "string" ? u : "";
    }

    FileView {
        id: ics
        path: root.icsUrl
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.raw = text();
            // ICS parse is optional — keep events empty rather than guess.
            root.events = [];
        }
        onLoadFailed: {
            root.raw = "";
            root.events = [];
            if (root.icsUrl.length > 0)
                Logger.warn("Calendar", "failed to load ICS from " + root.icsUrl);
        }
    }
}
