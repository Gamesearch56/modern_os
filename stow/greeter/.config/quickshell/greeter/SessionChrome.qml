// Shared session chrome for the greetd package. Desktop Commons cannot
// be imported here (different stow user), so tokens and strings are
// snapshotted into /var/lib/modern/session by wallpaper-sync.sh.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    readonly property var color: root._color
    readonly property var chrome: root._chrome
    readonly property string fontFamily: String(root._chrome.typography?.ui || "Inter")
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
    readonly property real radiusFull: 9999
    readonly property real overlayLock: 0.48
    readonly property real strokeHairline: 1
    readonly property real strokeFocus: 2
    readonly property real fieldHeight: root.spaceXxl + root.spaceXs
    readonly property real formWidth: root.spaceXxl * 12

    readonly property var _fallbackColor: ({
        surface: "#141218",
        onSurface: "#E6E0E9",
        onSurfaceVariant: "#CAC4D0",
        primary: "#D0BCFF",
        onPrimary: "#381E72",
        primaryContainer: "#4F378B",
        onPrimaryContainer: "#EADDFF",
        surfaceContainerHighest: "#36343B",
        outline: "#938F99",
        scrim: "#000000",
        error: "#ffb4ab"
    })

    property var _color: root._fallbackColor
    property var _chrome: ({
        strings: {},
        typography: { ui: "Inter", scale: 1 },
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
        if (key === "session.unlock")
            return s.unlock || "Unlock";
        if (key === "session.password")
            return s.password || "Password";
        if (key === "session.user")
            return s.user || "User";
        if (key === "session.signingIn")
            return s.signingIn || "Signing in…";
        if (key === "session.authFailed")
            return s.authFailed || "Could not unlock";
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
        if (name === "titleMedium" || name === "labelLarge")
            return 500;
        return 400;
    }

    function pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function formatTime(d: var): string {
        if (!d)
            return "";
        const p = root.timeFormat;
        if (p === "hh:mm a") {
            let h = d.getHours();
            const am = h < 12;
            h = h % 12;
            if (h === 0)
                h = 12;
            return root.pad(h) + ":" + root.pad(d.getMinutes()) + (am ? " AM" : " PM");
        }
        return root.pad(d.getHours()) + ":" + root.pad(d.getMinutes());
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
}
