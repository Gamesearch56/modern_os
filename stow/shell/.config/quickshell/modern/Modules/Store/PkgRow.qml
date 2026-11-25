import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MListItem {
    id: root

    property var pkg: ({})
    property bool removable: true
    property bool forceInstalled: false

    readonly property bool _on: root.forceInstalled || !!(pkg && pkg.installed)
    readonly property string _name: String(pkg && pkg.name || "")
    readonly property string _icon: Store.iconForPkg(root._name)
    readonly property bool _themeIcon: root._icon.indexOf("-symbolic") !== -1
    readonly property bool update: Store.hasUpdate(root._name)

    iconName: root._icon
    tintIcon: root._themeIcon
    preferSymbolic: root._themeIcon
    hoverHighlight: true
    titleValue: Store.titleFor(root._name)
    subtitleValue: root.update
        ? I18n.t("store.updateAvailable")
        : Store.descFor(root._name, String(pkg && pkg.desc || ""))
    onClicked: Store.showPackage(root._name)

    PkgAction {
        pkgName: root._name
        installed: root._on
        removable: root.removable
    }
}
