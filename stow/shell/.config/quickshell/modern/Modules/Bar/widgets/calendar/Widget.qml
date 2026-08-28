import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: "x-office-calendar"
        key: "calendar.title"
        onClicked: Settings.openAt("accounts", "calendar")
    }
}
