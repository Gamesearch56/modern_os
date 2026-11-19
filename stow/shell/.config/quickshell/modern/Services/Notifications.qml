// Notification server. Replaces SwayNC. Banners are `toasts`; `list` is
// history until the user dismisses. Timeout hides the banner only.
pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var list: []
    property var toasts: []
    readonly property int unread: root.list.filter(n => n && !n.read).length
    property bool dnd: false
    property bool panelOpen: false
    property var _lastLocal: ({ key: "", at: 0 })
    property int _minute: 0
    property int _nextId: 1
    readonly property int timeoutMs: {
        const n = Number(Config.general.notificationTimeoutMs);
        return n > 0 ? n : 6000;
    }

    readonly property bool scheduledDnd: {
        void root._minute;
        const s = Config.general.dndSchedule;
        if (!s || !s.enabled)
            return false;
        const a = root._hm(s.from);
        const b = root._hm(s.to);
        if (a < 0 || b < 0 || a === b)
            return false;
        const t = root._minute;
        return a < b ? (t >= a && t < b) : (t >= a || t < b);
    }
    readonly property bool effectiveDnd: root.dnd || root.scheduledDnd

    Timer {
        interval: 60000
        running: !!(Config.general.dndSchedule && Config.general.dndSchedule.enabled)
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const n = new Date();
            root._minute = n.getHours() * 60 + n.getMinutes();
        }
    }

    function _hm(s: string): int {
        const p = String(s || "").split(":");
        const h = Number(p[0]);
        const m = Number(p[1] || 0);
        if (h !== h || m !== m || h < 0 || h > 23 || m < 0 || m > 59)
            return -1;
        return h * 60 + m;
    }

    onPanelOpenChanged: {
        if (!root.panelOpen)
            return;
        for (const n of root.list)
            n.read = true;
        root.list = root.list.slice();
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        extraHints: ["x-kde-urls"]
        onNotification: (notification) => {
            try {
                if (root.effectiveDnd) {
                    notification.tracked = true;
                    return;
                }
                const item = root._wrap(notification);
                notification.tracked = true;
                root._push(item);
            } catch (e) {
                console.error("Notifications: " + e);
            }
        }
    }

    Connections {
        target: Logger
        function onLogged(level, tag, message) {
            if (level === "error")
                root.postLocal(level, tag, message);
            else if (level === "warn" && Logger.notifyOnWarn)
                root.postLocal(level, tag, message);
        }
    }

    function _str(v) {
        if (v === undefined || v === null)
            return "";
        const s = String(v);
        return (!s.length || s === "undefined") ? "" : s;
    }

    function _timeoutMs() {
        return root.timeoutMs;
    }

    function _wrap(n) {
        const protocol = n.expireTimeout;
        const resident = n.resident === true || protocol === 0;
        const item = {
            uid: root._nextId++,
            raw: n,
            summary: root._str(n.summary),
            body: root._str(n.body),
            appName: root._str(n.appName),
            appIcon: root._str(n.appIcon),
            desktopEntry: root._str(n.desktopEntry),
            image: root._str(n.image),
            hints: n.hints || ({}),
            local: false,
            toastVisible: true,
            read: false,
            expireTimeout: resident ? 0 : root._timeoutMs(),
            shownAt: Date.now()
        };
        try {
            n.closed.connect(() => root._drop(item.uid));
        } catch (e) {
            console.error("Notifications: " + e);
        }
        return item;
    }

    function _local(summary, body, image, expireTimeout) {
        return {
            uid: root._nextId++,
            raw: null,
            summary: summary,
            body: body || "",
            appName: "modern",
            appIcon: "",
            desktopEntry: "",
            image: image || "",
            hints: ({}),
            local: true,
            toastVisible: true,
            read: false,
            expireTimeout: Number(expireTimeout) > 0 ? Number(expireTimeout) : 0,
            shownAt: Date.now()
        };
    }

    function _push(item) {
        const next = root.list.slice();
        next.unshift(item);
        root.list = next;
        root._syncToasts();
    }

    function _syncToasts() {
        const shown = [];
        for (const n of root.list) {
            if (n && n.toastVisible)
                shown.push(n);
            if (shown.length >= 3)
                break;
        }
        root.toasts = shown;
    }

    // Scan the live list. createObject(Timer) stored a QVariant copy of
    // the JS item, so hideToast mutated a clone and the banner stayed.
    Timer {
        interval: Motion.shortMs > 0 ? Motion.shortMs : Motion.durationShort
        repeat: true
        running: root.toasts.length > 0
        onTriggered: root._expireDue()
    }

    function _expireDue() {
        const now = Date.now();
        let changed = false;
        for (const n of root.list) {
            if (!n || !n.toastVisible)
                continue;
            const ms = Number(n.expireTimeout);
            if (!(ms > 0))
                continue;
            const shown = Number(n.shownAt);
            if (!(shown > 0) || now < shown + ms)
                continue;
            n.toastVisible = false;
            changed = true;
        }
        if (!changed)
            return;
        root.list = root.list.slice();
        root._syncToasts();
    }

    function hideToast(item) {
        const live = root._live(item);
        if (!live || !live.toastVisible)
            return;
        live.toastVisible = false;
        root.list = root.list.slice();
        root._syncToasts();
    }

    function postLocal(level, tag, message) {
        const key = level + "\x1f" + tag + "\x1f" + message;
        const now = Date.now();
        if (root._lastLocal.key === key && (now - root._lastLocal.at) < 8000)
            return;
        root._lastLocal = { key: key, at: now };
        if (root.effectiveDnd && level !== "error")
            return;
        const summaryKey = level === "error" ? "notifications.shellError" : "notifications.shellWarning";
        const expire = root._timeoutMs();
        root._push(root._local(I18n.t(summaryKey), message, "", expire));
    }

    function toast(summary: string, body: string, imagePath) {
        if (root.effectiveDnd)
            return;
        root._push(root._local(summary, body || "", imagePath || "", root._timeoutMs()));
    }

    function _isLocalPath(s: string): bool {
        const t = String(s || "");
        return t.indexOf("/") === 0 || t.indexOf("file://") === 0;
    }

    function _themeName(s: string): bool {
        const t = String(s || "");
        return t.length > 0 && t.indexOf("/") === -1 && t.indexOf("://") === -1;
    }

    function _fileUrl(s: string): string {
        const t = String(s || "");
        if (!t.length)
            return "";
        if (t.indexOf("://") !== -1)
            return t;
        return t.indexOf("/") === 0 ? ("file://" + t) : "";
    }

    // Pixmap/file only — an icon *name* in image becomes file://name and
    // Qt paints the missing-image texture in the control panel list.
    function _rasterUrl(s: string): string {
        const t = String(s || "");
        if (!t.length || root._themeName(t))
            return "";
        const lower = t.toLowerCase();
        const fileish = root._isLocalPath(t)
            || lower.indexOf(".png") !== -1 || lower.indexOf(".jpg") !== -1
            || lower.indexOf(".jpeg") !== -1 || lower.indexOf(".webp") !== -1
            || lower.indexOf(".svg") !== -1
            || lower.indexOf("screenshot") !== -1
            || lower.indexOf("/pictures/") !== -1;
        if (!fileish)
            return "";
        return root._fileUrl(t) || t;
    }

    function _iconFile(name: string): string {
        if (!root._themeName(name))
            return "";
        const full = Quickshell.iconPath(name);
        const checked = Quickshell.iconPath(name, true);
        const p = (full && String(full).length) ? String(full) : String(checked || "");
        if (!p.length)
            return "";
        if (p.indexOf("://") !== -1 || p.indexOf("image:") === 0)
            return p;
        return p.charAt(0) === "/" ? ("file://" + p) : "";
    }

    function displayImage(item): string {
        const live = root._live(item) || item;
        if (!live)
            return "";
        const fromImage = root._rasterUrl(root._str(live.image));
        if (fromImage.length)
            return fromImage;
        const h = live.hints || ({});
        const fromHint = root._rasterUrl(root._str(h["image-path"] || h["image_path"]));
        if (fromHint.length)
            return fromHint;
        const fromApp = root._fileUrl(root._str(live.appIcon));
        if (fromApp.length)
            return fromApp;
        const named = root._iconFile(root._str(live.appIcon))
            || root._iconFile(root._str(live.image))
            || root._iconFile(root._str(live.desktopEntry).replace(/\.desktop$/i, ""));
        return named;
    }

    function displayIcon(item): string {
        const live = root._live(item) || item;
        if (!live)
            return "dialog-information-symbolic";
        const a = root._str(live.appIcon);
        if (root._themeName(a))
            return a;
        const img = root._str(live.image);
        if (root._themeName(img))
            return img;
        const d = root._str(live.desktopEntry).replace(/\.desktop$/i, "");
        if (d.length)
            return d;
        return "dialog-information-symbolic";
    }

    // Durable app icon (theme file or on-disk SVG). Notification pixmaps
    // under /tmp are valid for the banner and often gone in the list.
    function displayIconSource(item): string {
        const live = root._live(item) || item;
        if (!live)
            return "";
        const fromApp = root._fileUrl(root._str(live.appIcon));
        if (fromApp.length)
            return fromApp;
        return root._iconFile(root._str(live.appIcon))
            || root._iconFile(root._str(live.image))
            || root._iconFile(root._str(live.desktopEntry).replace(/\.desktop$/i, ""));
    }

    function _hintUrls(v): var {
        if (v && typeof v === "object" && v.length !== undefined) {
            const out = [];
            for (let i = 0; i < v.length; i++)
                out.push(String(v[i]));
            return out;
        }
        return root._str(v).split(/[\s,]+/);
    }

    function _openablePath(s: string): string {
        if (!root._isLocalPath(s))
            return "";
        const t = String(s);
        const low = t.toLowerCase();
        if (low.indexOf("scoped_dir") !== -1
            || low.indexOf("/tmp/.com.vivaldi") !== -1
            || low.indexOf("/tmp/.org.chromium") !== -1
            || low.indexOf("/tmp/.com.google.chrome") !== -1)
            return "";
        return t;
    }

    function attachmentPath(item): string {
        const live = root._live(item) || item;
        if (!live)
            return "";
        const h = live.hints || ({});
        const urls = root._hintUrls(h["x-kde-urls"]);
        for (let i = 0; i < urls.length; i++) {
            const p = root._openablePath(urls[i]);
            if (p.length)
                return p;
        }
        const file = root._str(live.body).match(/file:\/\/[^\s<>"']+/);
        if (file) {
            const p = root._openablePath(file[0]);
            if (p.length)
                return p;
        }
        const img = root._openablePath(root._str(live.image));
        if (img.length)
            return img;
        return root._openablePath(root._str(h["image-path"] || h["image_path"]));
    }

    function invokeDefault(item): bool {
        const live = root._live(item) || item;
        const raw = live ? live.raw : null;
        const acts = raw ? raw.actions : null;
        if (!acts || !acts.length)
            return false;
        try {
            let pick = acts[0];
            for (let i = 0; i < acts.length; i++) {
                const id = String(acts[i].identifier || "").toLowerCase();
                if (id === "default" || id === "")
                    pick = acts[i];
            }
            pick.invoke();
            return true;
        } catch (e) {
            Logger.error("Notifications", String(e));
            return false;
        }
    }

    function _normApp(s: string): string {
        return String(s || "").toLowerCase().replace(/\.desktop$/i, "").replace(/[\s._-]+/g, "");
    }

    function _browserId(id: string): bool {
        const n = root._normApp(id);
        return n === "vivaldi" || n === "vivaldistable" || n === "chromium"
            || n === "brave" || n === "bravebrowser" || n.indexOf("googlechrome") !== -1;
    }

    function _desktopByName(name: string): string {
        const want = root._normApp(name);
        if (!want.length || want === "modern" || root._browserId(want))
            return "";
        const heur = DesktopEntries.heuristicLookup(name);
        if (heur) {
            const stem = String(heur.id || "").replace(/\.desktop$/i, "");
            if (stem.length && !root._browserId(stem))
                return stem;
        }
        const entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const stem = String(e.id || e.name || "").replace(/\.desktop$/i, "");
            if (root._browserId(stem))
                continue;
            if (root._normApp(e.name) === want || root._normApp(stem) === want)
                return stem;
        }
        return "";
    }

    function _hostOf(url: string): string {
        const m = String(url || "").match(/^https?:\/\/([^\/"'<>\s]+)/i);
        if (!m)
            return "";
        return m[1].toLowerCase().replace(/:\d+$/, "");
    }

    // Chromium puts the site on the first line, or in a class-shaped
    // desktop entry (vivaldi-mail.proton.me__-Default). The browser's
    // own desktop id is the http handler, and raising that opens http://-.
    function _originHost(live): string {
        const body = root._str(live.body);
        const linked = body.match(/https?:\/\/[^\/"'<>\s]+/i);
        if (linked)
            return root._hostOf(linked[0]);
        const d = root._str(live.desktopEntry);
        const cls = d.match(/^(?:vivaldi|chrome|chromium|brave)-(.+?)__-/i);
        return cls ? cls[1].toLowerCase() : "";
    }

    function _desktopForHost(host: string): string {
        if (!host.length)
            return "";
        const entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const exec = String(e.execString || "");
            const m = exec.match(/--app=https?:\/\/([^\/\s]+)/i);
            if (!m || m[1].toLowerCase().replace(/:\d+$/, "") !== host)
                continue;
            const stem = String(e.id || "").replace(/\.desktop$/i, "");
            if (stem.length && !root._browserId(stem))
                return stem;
        }
        return "";
    }

    function _appDesktopId(live): string {
        const byHost = root._desktopForHost(root._originHost(live));
        if (byHost.length)
            return byHost;
        const byName = root._desktopByName(root._str(live.appName));
        if (byName.length)
            return byName;
        const d = root._str(live.desktopEntry).replace(/\.desktop$/i, "");
        if (d.length && !root._browserId(d))
            return d;
        const bySummary = root._desktopByName(root._str(live.summary));
        if (bySummary.length)
            return bySummary;
        return "";
    }

    function activate(item): bool {
        const live = root._live(item) || item;
        if (!live)
            return false;
        // Shell toasts carry the file they report (screenshot, recording,
        // fetched wallpaper): show it selected in the file manager.
        if (live.local) {
            const file = root._openablePath(root._str(live.image));
            const shown = file.length > 0 && Apps.openInFileManager(file);
            if (shown)
                root.hide();
            root.dismiss(live);
            return shown;
        }
        // The app's own action comes first even when its window is up:
        // raising alone never opens the chat or mail the banner was about.
        const id = root._appDesktopId(live);
        const invoked = root.invokeDefault(live);
        // A browser-named notification must not focus the browser window.
        // The site's installed app is `id`.
        const raiseName = root._browserId(live.appName) ? "" : root._str(live.appName);
        // Raise after the action so the opened mail is on the window
        // that then comes to this workspace. A miss starts the app only
        // once Hyprland confirms it has no window, including one parked
        // on the background workspace.
        Hypr.raiseApp(id, raiseName, () => {
            if (id.length)
                Apps.launchId(id);
            else if (!invoked) {
                const path = root.attachmentPath(live);
                if (path.length)
                    Apps.openPath(path);
            }
        });
        root.hide();
        root.dismiss(live);
        return true;
    }

    function _byUid(uid) {
        const id = Number(uid);
        if (!(id > 0))
            return null;
        for (const n of root.list) {
            if (Number(n.uid) === id)
                return n;
        }
        return null;
    }

    function _live(item) {
        if (item === undefined || item === null)
            return null;
        if (typeof item === "number" || typeof item === "string")
            return root._byUid(item);
        const byUid = root._byUid(item.uid);
        if (byUid)
            return byUid;
        for (const n of root.list) {
            if (n === item || (item.raw && n.raw === item.raw))
                return n;
        }
        return null;
    }

    function _drop(uid) {
        const id = Number(uid);
        if (!(id > 0))
            return;
        const next = [];
        let hit = false;
        for (const n of root.list) {
            if (Number(n.uid) === id) {
                hit = true;
                continue;
            }
            next.push(n);
        }
        if (!hit)
            return;
        root.list = next;
        root._syncToasts();
    }

    function dismiss(item) {
        const live = root._live(item);
        if (!live)
            return;
        const raw = live.raw;
        root._drop(live.uid);
        try {
            if (raw)
                raw.dismiss();
        } catch (e) {
            Logger.error("Notifications", String(e));
        }
    }

    function dismissAll() {
        const items = root.list.slice();
        root.list = [];
        root.toasts = [];
        for (const n of items) {
            try {
                if (n.raw)
                    n.raw.dismiss();
            } catch (e) {
                Logger.error("Notifications", String(e));
            }
        }
    }

    function toggleDnd() { root.dnd = !root.dnd; }
    function toggle() { root.panelOpen = !root.panelOpen; }
    function show() { root.panelOpen = true; }
    function hide() { root.panelOpen = false; }

    IpcHandler {
        target: "notifications"
        function toggle() { root.toggle(); }
        function show() { root.show(); }
        function hide() { root.hide(); }
        function toast(summary: string, body: string) { root.toast(summary, body, ""); }
    }
}
