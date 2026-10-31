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
    clip: true
    implicitHeight: root.vertical ? Math.max(Config.bar.height, inner.implicitHeight) : Config.bar.height
    implicitWidth: root.vertical ? Config.bar.height : Math.max(Config.bar.height, inner.implicitWidth)
    // Parent is a layout. Hints follow the pill so a late chip width
    // pushes the neighbors over instead of drawing under them.
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.fillWidth: false
    Layout.fillHeight: false

    default property alias extra: inner.data

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: Colors.color.surface
        opacity: Chrome.washOpacity
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.full
        color: "transparent"
        border.width: Tokens.stroke.hairline
        border.color: Colors.color.outlineVariant
    }

    // Positioner, not GridLayout: a layout assigns child widths and
    // drops a width binding, which left the battery slot at 0.
    Grid {
        id: inner
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.left: root.vertical ? undefined : parent.left
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.top: root.vertical ? parent.top : undefined
        columns: root.vertical ? 1 : 32
        rows: root.vertical ? 32 : 1
        columnSpacing: 0
        rowSpacing: 0
    }
}
