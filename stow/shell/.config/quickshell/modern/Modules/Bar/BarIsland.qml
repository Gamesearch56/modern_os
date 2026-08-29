// Island chrome: wallpaper `surface` at design.transparency (same glass
// as the control panel). Do not clip — popups are PopupWindows now.
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property bool empty: false
    property bool vertical: false

    visible: !root.empty
    implicitHeight: root.vertical ? Math.max(Tokens.spacing.xxl, inner.implicitHeight + Tokens.spacing.sm * 2) : Config.bar.height
    implicitWidth: root.vertical ? Config.bar.height : Math.max(Tokens.spacing.xl, inner.implicitWidth + Tokens.spacing.sm * 2)

    default property alias extra: inner.data

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surface
        opacity: Config.design.transparency ?? 0.85
        border.width: Tokens.stroke.hairline
        border.color: Colors.color.outlineVariant

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colors.color.primary
            opacity: Chrome.stateLayer(hover.hovered, false)
        }
    }

    HoverHandler {
        id: hover
    }

    GridLayout {
        id: inner
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 16
        rows: root.vertical ? 16 : 1
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Tokens.spacing.xxs
        columnSpacing: Tokens.spacing.xxs
    }
}
