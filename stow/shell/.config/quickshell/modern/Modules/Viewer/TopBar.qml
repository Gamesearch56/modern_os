import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"
import "../../Widgets"

// The floating strip over the picture: which picture this is, how far it
// is zoomed, the common commands, and the full menu behind "more".
Rectangle {
    id: root

    property var actions: null
    property int percent: 100
    readonly property bool menuOpen: more.open
    readonly property var tools: ["zoomOut", "zoomIn", "fit", "rotateLeft", "rotateRight", "info", "fullscreen"]

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
            value: ViewerDoc.empty ? I18n.t("viewer.launcherName") : ViewerDoc.name
            styleName: "titleSmall"
            elide: Text.ElideMiddle
        }

        MText {
            visible: ViewerDoc.count > 1
            key: "viewer.position"
            params: ({ index: ViewerDoc.index + 1, count: ViewerDoc.count })
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }

        MText {
            visible: !ViewerDoc.empty
            Layout.leftMargin: Tokens.spacing.sm
            key: "viewer.percent"
            params: ({ percent: root.percent })
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }

        Repeater {
            model: ViewerDoc.empty ? [] : root.tools
            delegate: MIconButton {
                required property string modelData
                readonly property var def: root.actions ? root.actions.def(modelData) : null
                iconName: def ? def.icon : ""
                key: def ? def.key : ""
                tip: true
                enabled: !!root.actions && root.actions.enabled(modelData)
                checked: !!root.actions && root.actions.checked(modelData)
                onClicked: root.actions.run(modelData)
            }
        }

        MIconButton {
            id: moreButton
            iconName: "view-more"
            key: "viewer.more"
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
            key: "viewer.actions.close"
            close: true
            tip: true
            onClicked: root.actions.run("close")
        }
    }
}
