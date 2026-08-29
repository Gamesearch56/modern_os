import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.sm

    MSectionHeader {
        key: "bar.network"
        styleName: "headlineSmall"
    }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.wifi"
        MSwitch {
            checked: Network.wifiEnabled
            onToggled: (v) => Network.setWifiEnabled(v)
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: Network.networks
        delegate: MListItem {
            required property var modelData
            width: ListView.view.width
            iconName: "network-wireless"
            titleValue: modelData.ssid || modelData.name || ""
            subtitleValue: modelData.active ? I18n.t("network.ethernet") : ""
            selected: !!modelData.active
            onClicked: Network.connect(modelData, "")
        }

        MEmptyState {
            visible: parent.count === 0
            anchors.fill: parent
            iconName: "network-offline"
            titleKey: "network.disconnected"
        }
    }

    MButton {
        kind: "text"
        key: "settings.sections.network"
        fillWidth: true
        onClicked: Settings.openAt("network", "")
    }
}
