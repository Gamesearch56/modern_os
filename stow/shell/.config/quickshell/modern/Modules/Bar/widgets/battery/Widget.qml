import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    visible: Battery.onBattery
    implicitWidth: visible ? (BarLayout.vertical ? Config.bar.height : row.implicitWidth) : 0
    implicitHeight: visible ? (Tokens.spacing.xl + Tokens.spacing.xs) : 0

    Component.onCompleted: Battery.watching = true
    Component.onDestruction: Battery.watching = false

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIcon {
            name: Battery.iconName
            size: Tokens.icon.md
            color: Colors.color.onSurface
        }

        MText {
            visible: !BarLayout.vertical
            value: String(Battery.percent) + "%"
            styleName: "labelLarge"
            color: Colors.color.onSurface
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Settings.openAt("power", "")
    }
}
