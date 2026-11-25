import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property var pkg: ({})

    readonly property string pkgName: String(pkg && pkg.name || "")
    readonly property string iconName: Store.iconForPkg(root.pkgName)
    readonly property bool update: Store.hasUpdate(root.pkgName)

    implicitWidth: Tokens.store.tile
    implicitHeight: Tokens.store.tile + Tokens.spacing.xl
    Accessible.role: Accessible.Button
    Accessible.name: Store.titleFor(root.pkgName)
    Accessible.onPressAction: Store.showPackage(root.pkgName)

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.primary
        opacity: Chrome.stateLayer(ma.containsMouse, ma.pressed)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.xs

        Item {
            Layout.alignment: Qt.AlignHCenter
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

            Rectangle {
                visible: root.update
                anchors.right: parent.right
                anchors.top: parent.top
                width: Tokens.spacing.sm
                height: Tokens.spacing.sm
                radius: Tokens.radius.full
                color: Colors.color.primary
            }
        }

        MText {
            value: Store.titleFor(root.pkgName)
            styleName: "labelLarge"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.showPackage(root.pkgName)
    }
}
