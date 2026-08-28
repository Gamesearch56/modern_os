// Shared island chrome for bar groups. Same tinted surface as overlay
// cards so wallpaper chroma shows through the pills.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

Item {
    id: root

    property bool empty: false

    visible: !root.empty
    implicitHeight: Config.bar.height
    implicitWidth: Math.max(Tokens.spacing.xxl, row.implicitWidth + Tokens.spacing.sm * 2)

    default property alias extra: row.data

    MCard {
        anchors.fill: parent
        level: 1
        radius: Tokens.radius.full
        padding: Tokens.spacing.xs
        opacity: Config.design.transparency ?? 0.85

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: Tokens.spacing.xs
        }
    }
}
