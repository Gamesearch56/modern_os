import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    visible: Network.wifiEnabled

    signal networkClicked(var network)

    // NetworkManager's own background scan can be minutes old; the page
    // opening or Wi-Fi coming on asks for a fresh one.
    Component.onCompleted: Network.scan()

    Connections {
        target: Network
        function onWifiEnabledChanged() {
            if (Network.wifiEnabled)
                Network.scan();
        }
    }

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
            readonly property bool locked: Network.isLocked(net)
            readonly property bool online: !!(net.connected)
            readonly property bool remembered: Network.isKnown(net)
            readonly property int bars: Network.signalLevel(net)

            Layout.fillWidth: true
            iconName: locked ? "network-wireless-encrypted" : "network-wireless"
            titleValue: net.name || net.ssid || ""
            subtitleKey: online ? "settings.network.wifiConnected" : ""
            selected: online
            onClicked: root.networkClicked(net)

            // Every listed network was heard in the last scan, so a saved
            // one here can be joined now.
            titleAccessory: MTag {
                key: remembered && !online ? "settings.network.remembered" : ""
            }

            MSignal {
                level: bars
                label: I18n.t("settings.signal.bars", { n: bars })
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
