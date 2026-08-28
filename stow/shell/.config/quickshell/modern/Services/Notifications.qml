// Notification server. Replaces SwayNC. Modules/Notifications renders
// toasts and the drawer from `list`; this owns the protocol.
// Local shell errors arrive via Logger.logged (Commons cannot import us).
pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var list: []
    readonly property int unread: root.list.filter(n => n && !n.dismissed).length
    property bool dnd: false
    property bool panelOpen: false
    property var _lastLocal: ({ key: "", at: 0 })

    NotificationServer {
        id: server
        onNotification: (notification) => {
            try {
                notification.tracked = true;
                if (root.dnd)
                    return;
                const next = root.list.slice();
                next.unshift(notification);
                root.list = next;
                const timeout = Config.general.notificationTimeoutMs ?? 5000;
                if (timeout > 0 && notification.expireTimeout !== 0) {
                    const timer = Qt.createQmlObject("import QtQuick; Timer { running: true; repeat: false }", root);
                    timer.interval = timeout;
                    timer.triggered.connect(() => root.dismiss(notification));
                }
            } catch (e) {
                Logger.error("Notifications", String(e));
            }
        }
    }

    Connections {
        target: Logger
        function onLogged(level, tag, message) {
            try {
                if (level === "error")
                    root.postLocal(level, tag, message);
                else if (level === "warn" && Logger.notifyOnWarn)
                    root.postLocal(level, tag, message);
            } catch (e) {
                console.error("Notifications: failed to toast a log event: " + e);
            }
        }
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
        const item = {
            summary: I18n.t(summaryKey) + " · " + tag,
            body: message,
            appName: "modern",
            dismissed: false,
            local: true,
            expireTimeout: level === "error" ? 0 : (Config.general.notificationTimeoutMs ?? 5000)
        };
        const next = root.list.slice();
        next.unshift(item);
        root.list = next;
        if (item.expireTimeout > 0) {
            const timer = Qt.createQmlObject("import QtQuick; Timer { running: true; repeat: false }", root);
            timer.interval = item.expireTimeout;
            timer.triggered.connect(() => root.dismiss(item));
        }
    }

    function dismiss(notification: var) {
        root.list = root.list.filter(n => n !== notification);
        if (notification?.local)
            return;
        if (notification?.dismiss)
            notification.dismiss();
    }

    function dismissAll() {
        for (const n of root.list) {
            if (n?.local)
                continue;
            if (n?.dismiss)
                n.dismiss();
        }
        root.list = [];
    }

    function toggleDnd() {
        root.dnd = !root.dnd;
    }

    function toggle() { root.panelOpen = !root.panelOpen; }
    function show() { root.panelOpen = true; }
    function hide() { root.panelOpen = false; }
}
