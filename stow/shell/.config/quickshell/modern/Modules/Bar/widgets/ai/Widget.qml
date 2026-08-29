import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: "help-about-symbolic"
        key: "ai.title"
        onClicked: popup.open = !popup.open
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        elevation: 0
        implicitWidth: Tokens.spacing.xxl * 16
        implicitHeight: Tokens.spacing.xxl * 14

        Loader {
            anchors.fill: parent
            source: Qt.resolvedUrl("Panel.qml")
        }
    }
}
