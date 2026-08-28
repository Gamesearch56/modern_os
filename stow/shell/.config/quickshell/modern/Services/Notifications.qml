// Notification server. Replaces SwayNC. Modules/Notifications renders
// toasts and the drawer from `list`; this owns the protocol.
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

    NotificationServer {
        id: server
        onNotification: (notification) => {
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
        }
    }

    function dismiss(notification: var) {
        root.list = root.list.filter(n => n !== notification);
        if (notification?.dismiss)
            notification.dismiss();
    }

    function dismissAll() {
        for (const n of root.list) {
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
