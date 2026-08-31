import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MListItem {
    id: root

    property var pkg: ({})

    readonly property bool _on: !!(pkg && pkg.installed)
    readonly property string _name: String(pkg && pkg.name || "")

    iconName: root._name.length ? root._name : "package-x-generic-symbolic"
    tintIcon: false
    hoverHighlight: false
    titleValue: root._name
    subtitleValue: String(pkg && pkg.desc || "")
    badgeIcon: root._on ? "object-select-symbolic" : ""

    MButton {
        kind: root._on ? "destructive" : "filled"
        key: root._on ? "store.remove" : "store.install"
        enabled: Store.mutating.length === 0
        onClicked: {
            if (root._on)
                Store.requestRemove(root._name);
            else
                Store.requestInstall(root._name);
        }
    }
}
