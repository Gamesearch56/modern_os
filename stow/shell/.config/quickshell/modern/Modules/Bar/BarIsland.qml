// Island chrome: wallpaper `surface` at design.transparency (same glass
// as the control panel). Hover/active live on the inner hit target —
// never on this pill — so padding cannot light up without a click.
import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property bool empty: false
    property bool vertical: false
    property bool singleHit: true

    visible: !root.empty
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

    GridLayout {
        id: inner
        anchors.fill: parent
        columns: root.vertical ? 1 : 16
        rows: root.vertical ? 16 : 1
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: 0
    }
}
