import QtQuick
import QtQuick.Layouts
import "../../Commons"

Item {
    id: root

    property bool empty: false
    property bool vertical: false

    visible: !root.empty
    implicitHeight: root.vertical ? Math.max(Tokens.spacing.xxl, inner.implicitHeight + Tokens.spacing.sm * 2) : Config.bar.height
    implicitWidth: root.vertical ? Config.bar.height : Math.max(Tokens.spacing.xxl, inner.implicitWidth + Tokens.spacing.sm * 2)

    default property alias extra: inner.data

    MCard {
        anchors.fill: parent
        level: 1
        radius: Tokens.radius.full
        padding: Tokens.spacing.xs
        opacity: Config.design.transparency ?? 0.85

        GridLayout {
            id: inner
            anchors.centerIn: parent
            columns: root.vertical ? 1 : 16
            rows: root.vertical ? 16 : 1
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: Tokens.spacing.xs
            columnSpacing: Tokens.spacing.xs
        }
    }
}
