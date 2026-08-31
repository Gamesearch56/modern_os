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

    function _hintUrls(v): var {
        if (v && typeof v === "object" && v.length !== undefined) {
            const out = [];
            for (let i = 0; i < v.length; i++)
                out.push(String(v[i]));
            return out;
        }
        return root._str(v).split(/[\s,]+/);
    }

    function attachmentPath(item): string {
        const live = root._live(item) || item;
        if (!live)
            return "";
        const img = root._str(live.image);
        if (root._isLocalPath(img))
            return img;
        const h = live.hints || ({});
        const ip = root._str(h["image-path"] || h["image_path"]);
        if (root._isLocalPath(ip))
            return ip;
        const urls = root._hintUrls(h["x-kde-urls"]);
        for (let i = 0; i < urls.length; i++) {
            if (root._isLocalPath(urls[i]))
                return urls[i];
        }
        const m = root._str(live.body).match(/file:\/\/[^\s<>"']+/);
        if (m && root._isLocalPath(m[0]))
            return m[0];
        return "";
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
