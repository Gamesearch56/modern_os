// Island chrome: wallpaper `surface` at design.transparency (same glass
// as the control panel). Hover/active live on the inner hit target —
// never on this pill — so padding cannot light up without a click.
import QtQuick
import "../../Commons"

Item {
    id: root

    property bool empty: false
    property bool vertical: false
    property bool singleHit: true

    visible: !root.empty
    implicitHeight: Config.bar.height
    implicitWidth: root.vertical ? Config.bar.height : Math.max(Config.bar.height, inner.implicitWidth)

    default property alias extra: inner.data

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surface
        opacity: Config.design.transparency ?? 0.85
        border.width: Tokens.stroke.hairline
        border.color: Colors.color.outlineVariant
    }

    Grid {
        id: inner
        anchors.left: parent.left
        anchors.top: parent.top
        columns: root.vertical ? 1 : 32
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        spacing: 0
    }
}
