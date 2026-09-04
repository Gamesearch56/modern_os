// Shared session chrome for the greetd package. Desktop Commons cannot
// be imported here (different stow user), so tokens and strings are
// snapshotted into /var/lib/modern/session by wallpaper-sync.sh.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    readonly property var color: root._color
    readonly property string fontFamily: String(root._chrome.typography?.ui || "sans-serif")
    readonly property real typeScale: {
        const s = Number(root._chrome.typography?.scale);
        return (s > 0) ? s : 1;
    }
    readonly property real cornerScale: {
        const s = Number(root._chrome.design?.cornerRounding);
        return (s > 0) ? s : 1;
    }
    readonly property string timeFormat: String(root._chrome.language?.timeFormat || "HH:mm")
    readonly property string dateFormat: String(root._chrome.language?.dateFormat || "DD.MM.YYYY")

    readonly property real spaceXs: 4
    readonly property real spaceSm: 8
    readonly property real spaceMd: 12
    readonly property real spaceLg: 16
    readonly property real spaceXl: 24
    readonly property real spaceXxl: 32
    readonly property real radiusSmall: 8 * root.cornerScale
    readonly property real radiusMedium: 16 * root.cornerScale
    readonly property real radiusFull: 9999
    readonly property real overlayLock: 0.32
    readonly property real closedScale: 0.92
    readonly property real motionScale: {
        const s = Number(root._chrome.motion?.scale);
        if (s !== s || s < 0)
            return 1;
        return s;
    }
    readonly property int extraLongMs: {
        const base = Number(root._chrome.motion?.extraLong);
        const ms = (base > 0) ? base : 600;
        return Math.round(ms * root.motionScale);
    }
    readonly property bool overlaysFade: root.motionScale !== 0 && String(root._chrome.motion?.overlay || "fadeZoom") !== "zoom"
    readonly property bool overlaysZoom: root.motionScale !== 0 && String(root._chrome.motion?.overlay || "fadeZoom") !== "fade"
    readonly property var easingDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var easingAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property real transparency: {
        const t = Number(root._chrome.design?.transparency);
        return (t > 0 && t <= 1) ? t : 0.85;
    }
    readonly property real strokeHairline: 1
    readonly property real strokeFocus: 2
    readonly property real fieldHeight: root.spaceXxl + root.spaceXs
    readonly property real formWidth: root.spaceXxl * 11
    readonly property real iconMd: 24
    readonly property real iconLg: 28
    readonly property real avatarSize: root.spaceXxl * 2
    readonly property real hoverLayer: 0.08

    readonly property var _fallbackColor: ({
        surface: "#141218",
        onSurface: "#E6E0E9",
        onSurfaceVariant: "#CAC4D0",
        primary: "#D0BCFF",
        onPrimary: "#381E72",
        primaryContainer: "#4F378B",
        onPrimaryContainer: "#EADDFF",
        surfaceContainer: "#211F26",
        surfaceContainerHigh: "#2B2930",
        surfaceContainerHighest: "#36343B",
        outline: "#938F99",
        outlineVariant: "#49454F",
        scrim: "#000000",
        error: "#ffb4ab"
    })

    property var _color: root._fallbackColor
    property var _chrome: ({
        strings: {},
        typography: { ui: "sans-serif", scale: 1 },
        design: { cornerRounding: 1 },
        language: { timeFormat: "HH:mm", dateFormat: "DD.MM.YYYY" }
    })

    FileView {
        path: "/var/lib/modern/session/chrome.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data)
                    root._chrome = data;
            } catch (e) {
                /* keep fallback */
            }
        }
    }

    FileView {
        path: "/var/lib/modern/session/tokens.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data.color)
                    root._color = Object.assign({}, root._fallbackColor, data.color);
            } catch (e) {
                root._color = root._fallbackColor;
            }
        }
        onLoadFailed: root._color = root._fallbackColor
    }

    function t(key: string): string {
        const s = root._chrome.strings || ({});
        const table = ({
            "session.unlock": s.unlock || "Unlock",
            "session.password": s.password || "Password",
            "session.user": s.user || "User",
            "session.signingIn": s.signingIn || "Signing in…",
            "session.authFailed": s.authFailed || "Could not unlock",
            "session.signIn": s.signIn || "Sign in",
            "session.welcome": s.welcome || "Welcome",
            "session.loginFailed": s.loginFailed || "Could not sign in",
            "session.unavailable": s.unavailable || "Sign-in is not available",
            "session.capsLock": s.capsLock || "Caps Lock is on",
            "powerMenu.restart": s.restart || "Restart",
            "powerMenu.poweroff": s.poweroff || "Shut down",
            "powerMenu.title": s.power || "Power"
        });
        if (table[key])
            return table[key];
        if (key.indexOf("time.weekday.") === 0) {
            const day = key.slice("time.weekday.".length);
            return String((s.weekday || ({}))[day] || "");
        }
        return key;
    }

    function typePx(name: string): int {
        const sizes = ({
            displayLarge: 57,
            headlineSmall: 24,
            titleMedium: 16,
            bodyLarge: 16,
            bodySmall: 12,
            labelLarge: 14
        });
        return Math.round((sizes[name] || 16) * root.typeScale);
    }

    function typeWeight(name: string): int {
        if (name === "titleMedium" || name === "labelLarge" || name === "headlineSmall")
            return 500;
        return 400;
    }

    function overlayOpacity(open: bool): real {
        return open ? 1 : 0;
    }

    function overlayScale(open: bool): real {
        if (!root.overlaysZoom)
            return 1;
        return open ? 1 : root.closedScale;
    }

    function pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function weekday(d: var): string {
        if (!d)
            return "";
        const keys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        return root.t("time.weekday." + keys[d.getDay()]);
    }

    function formatTime(d: var): string {
        if (!d)
            return "";
        const sec = ":" + root.pad(d.getSeconds());
        const p = root.timeFormat;
        if (p === "hh:mm a") {
            let h = d.getHours();
            const am = h < 12;
            h = h % 12;
            if (h === 0)
                h = 12;
            return root.pad(h) + ":" + root.pad(d.getMinutes()) + sec + (am ? " AM" : " PM");
        }
        return root.pad(d.getHours()) + ":" + root.pad(d.getMinutes()) + sec;
    }

    function formatDate(d: var): string {
        if (!d)
            return "";
        const dd = root.pad(d.getDate());
        const mm = root.pad(d.getMonth() + 1);
        const yyyy = String(d.getFullYear());
        const p = root.dateFormat;
        if (p === "YYYY-MM-DD")
            return yyyy + "-" + mm + "-" + dd;
        if (p === "MM/DD/YYYY")
            return mm + "/" + dd + "/" + yyyy;
        return dd + "." + mm + "." + yyyy;
    }

    function formatDateLine(d: var): string {
        const w = root.weekday(d);
        const date = root.formatDate(d);
        if (w.length)
            return w + "  " + date;
        return date;
    }
}
