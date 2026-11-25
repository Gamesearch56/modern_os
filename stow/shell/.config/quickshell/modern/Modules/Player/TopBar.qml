import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"
import "../../Widgets"

// The floating strip over the video: what is playing, where it is in the
// list, the full menu behind "more", and close.
Rectangle {
    id: root

    property var actions: null
    readonly property bool menuOpen: more.open

    implicitHeight: row.implicitHeight + Tokens.spacing.sm * 2
    radius: Tokens.radius.full
    color: Colors.color.surfaceContainer
    border.color: Colors.color.outlineVariant
    border.width: Tokens.stroke.hairline

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.lg
        anchors.rightMargin: Tokens.spacing.sm
        spacing: Tokens.spacing.xs

        MText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            value: PlayerDoc.empty ? I18n.t("player.launcherName") : PlayerDoc.name
            styleName: "titleSmall"
            elide: Text.ElideMiddle
        }

        MText {
            visible: PlayerDoc.count > 1
            Layout.rightMargin: Tokens.spacing.sm
            key: "player.position"
            params: ({ index: PlayerDoc.index + 1, count: PlayerDoc.count })
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }

        MIconButton {
            iconName: "view-more"
            key: "player.more"
            tip: true
            highlighted: more.open
            onClicked: more.open = !more.open

            MActionMenu {
                id: more
                actions: root.actions
                items: root.actions ? root.actions.menuItems() : []
            }
        }

        MIconButton {
            iconName: "window-close"
            key: "player.actions.close"
            close: true
            tip: true
            onClicked: root.actions.run("close")
        }
    }
}
