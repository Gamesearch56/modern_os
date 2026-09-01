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

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.xl
        spacing: Tokens.spacing.md
        MText {
            key: "settings.network.nearby"
            styleName: "titleSmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MIconButton {
            iconName: "view-refresh"
            key: "settings.refresh"
            iconSize: Tokens.icon.sm
            busy: Network.scanning
            enabled: Network.wifiEnabled && !Network.scanning
            onClicked: Network.scan()
        }
    }

    MLinearProgress {
        visible: Network.scanning && Network.networks.length > 0
        Layout.fillWidth: true
        indeterminate: true
    }

    Repeater {
        model: Network.networks.length
        MListItem {
            required property int index
            readonly property var net: Network.networks[index] || ({})
            readonly property bool locked: Network.needsPassword(net)
            readonly property bool online: !!(net.connected)
            readonly property bool remembered: !!(net.known)

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

            Rectangle {
                visible: remembered && !online
                implicitHeight: Tokens.spacing.lg + Tokens.spacing.xs
                implicitWidth: savedLabel.implicitWidth + Tokens.spacing.sm * 2
                radius: Tokens.radius.full
                color: Colors.color.primaryContainer
                Accessible.role: Accessible.StaticText
                Accessible.name: I18n.t("settings.network.remembered")

                MText {
                    id: savedLabel
                    anchors.centerIn: parent
                    key: "settings.network.remembered"
                    styleName: "labelSmall"
                    color: Colors.color.onPrimaryContainer
                }
            }

            MButton {
                visible: online
                kind: "tonal"
                key: "settings.disconnect"
                onClicked: Network.disconnect()
            }
        }
    }

    Item {
        visible: Network.networks.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4

        MEmptyState {
            anchors.fill: parent
            iconName: "network-wireless"
            titleKey: Network.scanning ? "settings.network.wifiSearching" : "settings.network.wifiEmpty"
        }

        MLinearProgress {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: Network.scanning
            indeterminate: true
        }
    }
}
