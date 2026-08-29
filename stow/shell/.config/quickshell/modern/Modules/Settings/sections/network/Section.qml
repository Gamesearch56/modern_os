import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property var pendingNet: null
    readonly property bool passwordOpen: root.pendingNet !== null

    Component.onCompleted: Network.watching = true
    Component.onDestruction: Network.watching = false

    MSectionHeader { key: "bar.network" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.wifi"
        MSwitch {
            checked: Network.wifiEnabled
            onToggled: (v) => Network.setWifiEnabled(v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.ethernet"
        subtitleKey: Network.wiredConnected ? "settings.network.ethernetOn" : "settings.network.ethernetOff"
        iconName: "network-wired"
    }
    Repeater {
        model: Network.networks.length
        MListItem {
            required property int index
            readonly property var net: Network.networks[index] || ({})
            readonly property bool locked: Network.needsPassword(net)
            Layout.fillWidth: true
            titleValue: net.ssid || net.name || ""
            iconName: locked ? "network-wireless-encrypted" : "network-wireless"
            selected: !!net.active
            onClicked: {
                if (net.active) {
                    Network.disconnect();
                    return;
                }
                if (locked)
                    root.pendingNet = net;
                else
                    Network.connect(net, "");
            }
            MButton {
                visible: !!net.active
                kind: "tonal"
                key: "settings.disconnect"
                onClicked: Network.disconnect()
            }
        }
    }

    MSectionHeader { key: "settings.fields.bitrate" }
    MText {
        key: "network.bitrateValue"
        params: ({
            rx: Network.rxMbps.toFixed(1),
            tx: Network.txMbps.toFixed(1)
        })
        styleName: "labelLarge"
    }
    MSparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl
        values: Network.bitrateSamples
    }

    MButton {
        kind: "filled"
        key: "settings.speedTestRun"
        enabled: !Network.speedTesting
        onClicked: Network.speedTest()
    }
    MLinearProgress {
        visible: Network.speedTesting
        Layout.fillWidth: true
        indeterminate: true
    }
    MText {
        visible: Network.speedMbps > 0
        key: "settings.speedTestResult"
        params: ({ n: Network.speedMbps.toFixed(1) })
        styleName: "bodyMedium"
    }
    MHint { key: "settings.hints.speedTest"; Layout.fillWidth: true }

    MField {
        labelKey: "settings.fields.mirrorCountry"
        MTextField {
            text: Config.network?.mirrorCountry ?? ""
            onAccepted: ConfigWrite.set("network.mirrorCountry", text)
        }
    }
    MField {
        labelKey: "settings.fields.dnsOverride"
        MTextField {
            text: (Config.network?.dnsOverride || []).join(", ")
            onAccepted: {
                const parts = text.split(",").map(s => s.trim()).filter(s => s.length > 0);
                ConfigWrite.set("network.dnsOverride", parts);
            }
        }
    }
}
