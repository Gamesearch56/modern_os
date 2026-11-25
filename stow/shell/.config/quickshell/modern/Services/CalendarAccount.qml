// Calendar credentials in gitignored secrets.json. Provider + Apple ID
// stay in config.json; the iCal token and app password do not.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    // Before secrets.json, the iCal link lived in config.json.
    readonly property string icsUrl: Secrets.value("calendar", "icsUrl")
        || String(Config.accounts?.calendarIcsUrl || "").trim()
    readonly property bool hasApplePassword: Secrets.value("calendar", "applePassword").length > 0

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
        if (!Secrets.put("calendar", { icsUrl: u, applePassword: "", appleAccount: "" }))
            return;
        if (u.length)
            ConfigWrite.set("accounts.calendarIcsUrl", "");
    }

    function saveApple(user: string, password: string) {
        const who = String(user || "").trim();
        if (!Secrets.put("calendar", { applePassword: password, appleAccount: who, icsUrl: "" }))
            return;
        ConfigWrite.set("widgets.clock.calendarAccount", who);
        ConfigWrite.set("accounts.calendarIcsUrl", "");
    }

    function disconnect() {
        if (!Secrets.put("calendar", { icsUrl: "", applePassword: "", appleAccount: "" }))
            return;
        ConfigWrite.set("widgets.clock.calendarProvider", "none");
        ConfigWrite.set("widgets.clock.calendarAccount", "");
        ConfigWrite.set("accounts.calendarIcsUrl", "");
    }
}
