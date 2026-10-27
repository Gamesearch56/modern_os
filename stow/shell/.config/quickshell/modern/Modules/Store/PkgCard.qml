import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MCard {
    id: root

    property var pkg: ({})

    readonly property bool on: !!(pkg && pkg.installed)
    readonly property bool locked: root.on && Store.isSystem(root.pkgName)
    readonly property string pkgName: String(pkg && pkg.name || "")
    readonly property string iconName: Store.iconForPkg(root.pkgName)

    level: 1
    padding: Tokens.spacing.sm

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.xs

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Tokens.spacing.xxl + Tokens.spacing.xl
            Layout.preferredHeight: Tokens.spacing.xxl + Tokens.spacing.xl

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.medium
                color: Colors.color.surfaceContainerHighest
            }

            MIcon {
                anchors.centerIn: parent
                name: root.iconName
                size: Tokens.icon.lg
                tint: root.iconName.indexOf("-symbolic") !== -1
                preferSymbolic: root.iconName.indexOf("-symbolic") !== -1
            }
        }

        MText {
            value: Store.titleFor(root.pkgName)
            styleName: "titleMedium"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        MText {
            value: Store.descFor(root.pkgName, String(pkg && pkg.desc || ""))
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        MButton {
            Layout.fillWidth: true
            kind: root.locked ? "outlined" : (root.on ? "destructive" : "filled")
            key: root.locked ? "store.systemPackage" : (root.on ? "store.remove" : "store.install")
            enabled: !root.locked && Store.mutating.length === 0
            onClicked: {
                if (root.on)
                    Store.requestRemove(root.pkgName);
                else
                    Store.requestInstall(root.pkgName);
            }
        }
    }
}
