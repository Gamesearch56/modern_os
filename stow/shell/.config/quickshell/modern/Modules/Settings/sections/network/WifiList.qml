import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    visible: Network.wifiEnabled

    signal requestPassword(var network)

    MSectionHeader {
        key: "settings.network.nearby"
        topMargin: Tokens.spacing.xl
    }

    Repeater {
        model: Network.networks.length
        MListItem {
            required property int index
            readonly property var net: Network.networks[index] || ({})
            readonly property bool locked: Network.needsPassword(net)
            readonly property bool online: !!(net.connected)

            Layout.fillWidth: true
            iconName: locked ? "network-wireless-encrypted" : "network-wireless"
            titleValue: net.name || net.ssid || ""
            subtitleKey: online ? "settings.network.wifiConnected" : ""
            selected: online
            onClicked: {
                if (online) {
                    Network.disconnect();
                    return;
                }
                if (locked)
                    root.requestPassword(net);
                else
                    Network.connect(net, "");
            }

            MButton {
                visible: online
                kind: "tonal"
                key: "settings.disconnect"
                onClicked: Network.disconnect()
            }
        }
    }

    MEmptyState {
        visible: Network.networks.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "network-wireless"
        titleKey: "settings.network.wifiEmpty"
    }
}
