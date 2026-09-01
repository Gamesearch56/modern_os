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
    clip: true
    implicitHeight: root.vertical ? Math.max(Config.bar.height, inner.implicitHeight) : Config.bar.height
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
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.left: root.vertical ? undefined : parent.left
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.top: root.vertical ? parent.top : undefined
        columns: root.vertical ? 1 : 32
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        spacing: 0
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
    }
}
