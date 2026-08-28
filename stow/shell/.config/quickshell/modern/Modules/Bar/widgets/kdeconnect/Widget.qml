import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs
    Component.onCompleted: KdeConnect.watching = true

    MIcon {
        name: KdeConnect.connectedCount > 0 ? "phone-connected" : "phone"
        size: Tokens.spacing.lg
    }

    MText {
        value: KdeConnect.connectedCount > 0
            ? I18n.t("kdeconnect.connected", { count: KdeConnect.connectedCount })
            : I18n.t("kdeconnect.off")
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: KdeConnect.refresh()
    }
}
