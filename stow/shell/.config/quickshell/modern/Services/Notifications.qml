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
        onNotification: (notification) => {
            try {
                if (root.dnd) {
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
        return Config.general.notificationTimeoutMs ?? 6000;
    }

    function _wrap(n) {
        const protocol = n.expireTimeout;
        const resident = n.resident === true || protocol === 0;
        return {
            raw: n,
            summary: root._str(n.summary),
            body: root._str(n.body),
            appName: root._str(n.appName),
            appIcon: root._str(n.appIcon),
            image: root._str(n.image),
            local: false,
            toastVisible: true,
            read: false,
            expireTimeout: resident ? 0 : root._timeoutMs(),
            shownAt: Date.now()
        };
    }

    function _local(summary, body, image, expireTimeout) {
        return {
            raw: null,
            summary: summary,
            body: body || "",
            appName: "modern",
            appIcon: "",
            image: image || "",
            local: true,
            toastVisible: true,
            read: false,
            expireTimeout: expireTimeout,
            shownAt: Date.now()
        };
    }

    function _push(item) {
        const next = root.list.slice();
        next.unshift(item);
        root.list = next;
        root._syncToasts();
        root._armHide(item);
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

    function _armHide(item) {
        if (!item.expireTimeout || item.expireTimeout <= 0)
            return;
        const timer = Qt.createQmlObject("import QtQuick; Timer { running: true; repeat: false }", root);
        timer.interval = item.expireTimeout;
        timer.triggered.connect(() => { item._timer = null; timer.destroy(); root.hideToast(item); });
        item._timer = timer;
    }

    function _stopTimer(item) {
        if (!item?._timer)
            return;
        item._timer.stop();
        item._timer.destroy();
        item._timer = null;
    }

    function hideToast(item) {
        if (!item || !item.toastVisible)
            return;
        item.toastVisible = false;
        root._syncToasts();
    }

    function postLocal(level, tag, message) {
        const key = level + "\x1f" + tag + "\x1f" + message;
        const now = Date.now();
        if (root._lastLocal.key === key && (now - root._lastLocal.at) < 8000)
            return;
        root._lastLocal = { key: key, at: now };
        if (root.dnd && level !== "error")
            return;
        const summaryKey = level === "error" ? "notifications.shellError" : "notifications.shellWarning";
        const expire = level === "error" ? 0 : root._timeoutMs();
        root._push(root._local(I18n.t(summaryKey) + " · " + tag, message, "", expire));
    }

    function toast(summary: string, body: string, imagePath) {
        if (root.dnd)
            return;
        root._push(root._local(summary, body || "", imagePath || "", root._timeoutMs()));
    }

    function dismiss(item) {
        root._stopTimer(item);
        root.list = root.list.filter(n => n !== item);
        root._syncToasts();
        if (item?.raw?.dismiss)
            item.raw.dismiss();
    }

    function dismissAll() {
        for (const n of root.list) {
            root._stopTimer(n);
            if (n?.raw?.dismiss)
                n.raw.dismiss();
        }
        root.list = [];
        root.toasts = [];
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
