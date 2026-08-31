import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    id: root
    spacing: Tokens.spacing.xs
    readonly property bool on: Config.kdeconnect.enabled

    Component.onCompleted: KdeConnect.watching = root.on
    Component.onDestruction: KdeConnect.watching = false
    onOnChanged: KdeConnect.watching = root.on

    MIcon {
        name: root.on && KdeConnect.connectedCount > 0 ? "phone-connected" : "phone"
        size: Tokens.spacing.lg
    }

    MText {
        visible: !BarLayout.vertical
        value: !root.on || KdeConnect.connectedCount === 0
            ? I18n.t("kdeconnect.off")
            : I18n.t("kdeconnect.connected", ({ count: KdeConnect.connectedCount }))
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.on
        onClicked: KdeConnect.refresh()
    }
}
