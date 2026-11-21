import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

// Pins an installed app's launcher to the dock, or unpins it.
MButton {
    id: root

    property string pkgName: ""
    property bool installed: false
    property var desktopIds: []

    readonly property string appId: Store.dockIdFor(root.pkgName, root.desktopIds)
    readonly property int dockIndex: {
        const list = Dock.apps();
        const key = root.appId.toLowerCase();
        for (let i = 0; key.length && i < list.length; i++) {
            if (list[i].toLowerCase() === key)
                return i;
        }
        return -1;
    }
    readonly property bool pinned: root.dockIndex >= 0
    visible: root.installed && DockLayout.enabled && root.appId.length > 0
    kind: root.pinned ? "outlined" : "tonal"
    key: root.pinned ? "store.removeFromDock" : "store.addToDock"
    onClicked: {
        if (root.pinned) {
            Dock.removeAt(root.dockIndex);
            return;
        }
        // New pins go before the trailing Files/Store/Settings group.
        const list = Dock.apps();
        let at = list.length;
        while (at > 0 && list[at - 1].indexOf("shell:") === 0)
            at--;
        Dock.insertAt(root.appId, at);
    }
}
