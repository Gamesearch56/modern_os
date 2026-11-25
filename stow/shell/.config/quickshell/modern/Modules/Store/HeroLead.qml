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

    level: 2
    padding: Tokens.spacing.lg
    highlighted: root.update
    color: Colors.color.primaryContainer

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        MText {
            value: Store.titleFor(root.pkgName)
            styleName: "headlineSmall"
            color: Colors.color.onPrimaryContainer
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.spacing.sm

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Tokens.store.heroIcon
                    Layout.preferredHeight: Tokens.store.heroIcon

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius.medium
                        color: Colors.color.surface
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
                    styleName: "bodyMedium"
                    color: Colors.color.onPrimaryContainer
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        PkgAction {
            Layout.alignment: Qt.AlignHCenter
            pkgName: root.pkgName
            installed: root.on
        }
    }

    MouseArea {
        z: -1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.showPackage(root.pkgName)
    }
}
