// Calendar credentials in gitignored secrets.json. Provider + Apple ID
// stay in config.json; the iCal token and app password do not.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string icsUrl: ""
    property bool hasApplePassword: false

    readonly property string provider: {
        const p = String(Config.widgets?.clock?.calendarProvider || "").trim();
        if (p.length)
            return p;
        return root.inferProvider(root.icsUrl);
    }
    readonly property string account: String(Config.widgets?.clock?.calendarAccount || "").trim()
    readonly property bool usesAppleId: root.provider === "apple" && root.hasApplePassword
    readonly property bool connected: root.usesAppleId
        ? root.account.length > 0
        : root.icsUrl.length > 0

    FileView {
        id: secretsFile
        path: Paths.configHome + "/modern/secrets.json"
        watchChanges: true
        printErrors: false
        onLoaded: root._ingest(text())
        onLoadFailed: {
            root.icsUrl = root._legacyUrl();
            root.hasApplePassword = false;
        }
    }

    function inferProvider(url: string): string {
        const u = String(url || "").toLowerCase();
        if (!u.length)
            return "none";
        if (u.indexOf("proton.me") !== -1 || u.indexOf("protonmail") !== -1)
            return "proton";
        if (u.indexOf("google.com") !== -1 || u.indexOf("googleusercontent.com") !== -1)
            return "google";
        if (u.indexOf("icloud.com") !== -1 || u.indexOf("caldav.icloud") !== -1)
            return "apple";
        return "ics";
    }

    function _openSite(url: string, draft: string) {
        Settings.reopenAt("bar", "clock", draft);
        Quickshell.execDetached(["xdg-open", url]);
    }

    function openProton() {
        root._openSite("https://calendar.proton.me/u/0/settings/calendars", "proton");
    }

    function openGoogle() {
        root._openSite("https://calendar.google.com/calendar/u/0/r/settings", "google");
    }

    function openAppleId() {
        root._openSite("https://account.apple.com/account/manage", "apple");
    }

    // Translation key for a link that cannot be this provider's calendar
    // feed, "" when it looks right. Catches the common paste of the
    // calendar's web page instead of its iCal link.
    function linkProblem(provider: string, url: string): string {
        const u = String(url || "").trim().toLowerCase();
        if (!u.length)
            return "";
        if (!/^(https?|webcals?):\/\//.test(u))
            return "calendar.linkNotUrl";
        if (provider === "google" && u.indexOf("calendar.google.com") !== -1 && u.indexOf("/ical/") === -1)
            return "calendar.linkGoogleWrong";
        if (provider === "proton" && u.indexOf("proton.me") !== -1 && u.indexOf("/url/") === -1)
            return "calendar.linkProtonWrong";
        if (provider === "apple" && u.indexOf("icloud.com") !== -1 && u.indexOf("/published/") === -1)
            return "calendar.linkAppleWrong";
        return "";
    }

    // Apple shows app passwords as abcd-efgh-ijkl-mnop; the fetch helper
    // accepts spaces or missing dashes, so only the letters are checked.
    function appPasswordLooksRight(pwd: string): bool {
        return /^[a-z]{16}$/i.test(String(pwd || "").replace(/[\s-]/g, ""));
    }

    function saveIcs(url: string) {
        const u = String(url || "").trim();
        const obj = root._readSecrets();
        if (!obj.calendar || typeof obj.calendar !== "object")
            obj.calendar = ({});
        if (u.length)
            obj.calendar.icsUrl = u;
        else
            delete obj.calendar.icsUrl;
        delete obj.calendar.applePassword;
        delete obj.calendar.appleAccount;
        root._writeSecrets(obj);
        root.icsUrl = u;
        root.hasApplePassword = false;
        if (u.length)
            ConfigWrite.set("accounts.calendarIcsUrl", "");
    }

    function saveApple(user: string, password: string) {
        const pwd = String(password || "").trim();
        const obj = root._readSecrets();
        if (!obj.calendar || typeof obj.calendar !== "object")
            obj.calendar = ({});
        const who = String(user || "").trim();
        if (pwd.length)
            obj.calendar.applePassword = pwd;
        else
            delete obj.calendar.applePassword;
        if (who.length)
            obj.calendar.appleAccount = who;
        else
            delete obj.calendar.appleAccount;
        delete obj.calendar.icsUrl;
        root._writeSecrets(obj);
        root.icsUrl = "";
        root.hasApplePassword = pwd.length > 0;
        ConfigWrite.set("widgets.clock.calendarAccount", String(user || "").trim());
        ConfigWrite.set("accounts.calendarIcsUrl", "");
    }

    function disconnect() {
        const obj = root._readSecrets();
        if (obj.calendar && typeof obj.calendar === "object") {
            delete obj.calendar.icsUrl;
            delete obj.calendar.applePassword;
            delete obj.calendar.appleAccount;
        }
        root._writeSecrets(obj);
        root.icsUrl = "";
        root.hasApplePassword = false;
        ConfigWrite.set("widgets.clock.calendarProvider", "none");
        ConfigWrite.set("widgets.clock.calendarAccount", "");
        ConfigWrite.set("accounts.calendarIcsUrl", "");
    }

    function _legacyUrl(): string {
        const u = Config.accounts?.calendarIcsUrl;
        return typeof u === "string" ? u.trim() : "";
    }

    function _ingest(raw: string) {
        let ics = "";
        let apple = false;
        try {
            const data = JSON.parse(String(raw || "{}")) || ({});
            const cal = data.calendar || ({});
            ics = String(cal.icsUrl || "").trim();
            apple = String(cal.applePassword || "").trim().length > 0;
        } catch (e) {
            ics = "";
        }
        if (!ics.length)
            ics = root._legacyUrl();
        root.icsUrl = ics;
        root.hasApplePassword = apple;
    }

    function _readSecrets(): var {
        try {
            return JSON.parse(secretsFile.text() || "{}") || ({});
        } catch (e) {
            return ({});
        }
    }

    function _writeSecrets(obj: var) {
        try {
            secretsFile.setText(JSON.stringify(obj, null, 2) + "\n");
        } catch (err) {
            Logger.error("Calendar", "secrets write failed");
        }
    }
}
