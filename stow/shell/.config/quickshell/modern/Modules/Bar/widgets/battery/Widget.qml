import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    visible: Battery.onBattery
    implicitWidth: visible ? row.implicitWidth + Tokens.spacing.sm : 0
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    Component.onCompleted: Battery.watching = true
    Component.onDestruction: Battery.watching = false

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIcon {
            name: Battery.iconName
            size: Tokens.icon.md
        }

        MText {
            value: String(Battery.percent) + "%"
            styleName: "labelLarge"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Settings.openAt("power", "")
    }
}
