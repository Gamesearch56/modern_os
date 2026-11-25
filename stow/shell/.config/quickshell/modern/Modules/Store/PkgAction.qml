import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MButton {
    id: root

    property string pkgName: ""
    property bool installed: false
    property bool removable: true

    readonly property bool locked: root.installed && Store.isSystem(root.pkgName)
    readonly property bool update: Store.hasUpdate(root.pkgName)
    readonly property bool admin: Store.canMutate

    visible: root.admin && root.pkgName.length > 0
        && (root.update || (!root.locked && (root.removable || !root.installed)))
    kind: root.update ? "filled" : (root.installed ? "destructive" : "filled")
    key: root.update ? "store.update" : (root.installed ? "store.remove" : "store.install")
    enabled: Store.mutating.length === 0
    onClicked: {
        if (root.update)
            Store.requestUpdate(root.pkgName);
        else if (!root.installed)
            Store.requestInstall(root.pkgName);
        else
            Store.requestRemove(root.pkgName);
    }
}
