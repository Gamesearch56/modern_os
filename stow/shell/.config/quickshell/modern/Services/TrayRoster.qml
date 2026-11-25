// Instantiator roster for StatusNotifier items. Same objectAt() vs
// .values cold-start pattern as MediaRoster.
import Quickshell.Services.SystemTray
import QtQuick

Instantiator {
    id: root

    signal changed()

    model: SystemTray.items
    asynchronous: false
    onObjectAdded: root.changed()
    onObjectRemoved: root.changed()

    delegate: Connections {
        required property var modelData
        target: modelData
        function onIdChanged() { root.changed(); }
        function onTitleChanged() { root.changed(); }
        function onIconChanged() { root.changed(); }
        function onCategoryChanged() { root.changed(); }
        Component.onCompleted: root.changed()
    }

    function list(): var {
        const out = [];
        const n = root.count;
        for (let i = 0; i < n; i++) {
            const c = root.objectAt(i);
            const p = c ? (c.target || c.modelData) : null;
            if (p)
                out.push(p);
        }
        if (out.length)
            return out;
        const vals = SystemTray.items ? SystemTray.items.values : null;
        if (vals && vals.length)
            return vals;
        return [];
    }
}
