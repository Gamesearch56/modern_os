import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MCard {
    id: root

    property var pkg: ({})

    readonly property bool on: !!(pkg && pkg.installed)
    readonly property string pkgName: String(pkg && pkg.name || "")
    readonly property string iconName: Store.iconForPkg(root.pkgName)
    readonly property bool update: Store.hasUpdate(root.pkgName)

    level: 1
    padding: Tokens.spacing.md
    highlighted: root.update
    color: Colors.color.surfaceContainerHigh

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            MText {
                value: Store.titleFor(root.pkgName)
                styleName: "titleMedium"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PkgAction {
                pkgName: root.pkgName
                installed: root.on
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            spacing: Tokens.spacing.md

            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Tokens.store.tileIcon
                Layout.preferredHeight: Tokens.store.tileIcon

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
                value: Store.descFor(root.pkgName, String(pkg && pkg.desc || ""))
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item { Layout.fillHeight: true }
    }

    MouseArea {
        z: -1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.showPackage(root.pkgName)
    }
}
