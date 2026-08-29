import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"
import "."

Item {
    id: root
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: "mail-message-new-symbolic"
        key: "ai.title"
        onClicked: popup.open = !popup.open
    }

    BarPopup {
        id: popup
        open: false
        width: Tokens.spacing.xxl * 14
        height: Tokens.spacing.xxl * 16

        Panel {
            anchors.fill: parent
        }
    }
}
