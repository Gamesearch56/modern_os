import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

RowLayout {
    id: root

    property var info: ({})

    readonly property string pkgName: String(info && info.name || Store.detailName)
    readonly property bool on: !!(info && info.installed)
    readonly property string iconName: Store.iconForPkg(root.pkgName)
    readonly property bool update: Store.hasUpdate(root.pkgName)
    readonly property bool adminKnown: Passwd.groups.length > 0

    spacing: Tokens.spacing.lg
    Layout.fillWidth: true

    Rectangle {
        Layout.preferredWidth: Tokens.spacing.xxl * 3
        Layout.preferredHeight: Tokens.spacing.xxl * 3
        radius: Tokens.radius.medium
        color: Colors.color.surfaceContainerHighest

        MIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: Tokens.icon.lg * 2
            tint: root.iconName.indexOf("-symbolic") !== -1
            preferSymbolic: root.iconName.indexOf("-symbolic") !== -1
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs

        MText {
            value: Store.titleFor(root.pkgName)
            styleName: "headlineSmall"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        RowLayout {
            spacing: Tokens.spacing.sm
            MChip {
                value: String(root.info.repo || "")
                visible: String(root.info.repo || "").length > 0
                interactive: false
            }
            MChip {
                key: "store.official"
                interactive: false
            }
            MChip {
                key: "store.updateAvailable"
                visible: root.update
                checked: true
                interactive: false
            }
        }
        MHint {
            visible: root.adminKnown && !Store.canMutate
            key: "store.adminOnly"
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.sm
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: Tokens.spacing.sm

        DockAction {
            installed: root.on
            pkgName: root.pkgName
            desktopIds: root.info && root.info.desktop ? root.info.desktop : []
        }
        PkgAction {
            pkgName: root.pkgName
            installed: root.on
        }
    }
}
