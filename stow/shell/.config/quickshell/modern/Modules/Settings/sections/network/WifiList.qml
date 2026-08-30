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
        MouseArea {
            required property int index
            readonly property var net: Network.networks[index] || ({})
            readonly property bool locked: Network.needsPassword(net)
            readonly property bool online: !!(net.connected)

            Layout.fillWidth: true
            implicitHeight: row.implicitHeight
            implicitWidth: row.implicitWidth
            cursorShape: Qt.PointingHandCursor
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

            RowLayout {
                id: row
                width: parent.width
                spacing: Tokens.spacing.md

                MIcon {
                    name: locked ? "network-wireless-encrypted" : "network-wireless"
                    size: Tokens.icon.md
                }
                ColumnLayout {
                    spacing: Tokens.spacing.xxs
                    Layout.fillWidth: true
                    MText {
                        value: net.name || net.ssid || ""
                        styleName: "bodyLarge"
                        Layout.fillWidth: true
                    }
                    MText {
                        visible: online
                        key: "settings.network.wifiConnected"
                        styleName: "bodySmall"
                        color: Colors.color.onSurfaceVariant
                        Layout.fillWidth: true
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
    }

    MEmptyState {
        visible: Network.networks.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "network-wireless"
        titleKey: "settings.network.wifiEmpty"
    }
}
