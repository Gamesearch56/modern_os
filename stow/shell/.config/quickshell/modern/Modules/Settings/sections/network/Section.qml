import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

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
    Repeater {
        model: Network.networks
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.ssid || modelData.name || ""
            selected: !!modelData.active
            onClicked: Network.connect(modelData, "")
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
    Row {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xxs
        Repeater {
            model: Network.bitrateSamples
            Rectangle {
                required property var modelData
                width: Tokens.spacing.xs
                height: Math.max(Tokens.spacing.xs, Math.min(Tokens.spacing.xxl, Number(modelData) * Tokens.spacing.md))
                radius: Tokens.radius.full
                color: Colors.color.primary
                anchors.bottom: parent.bottom
            }
        }
    }

    MField {
        labelKey: "settings.fields.mirrorCountry"
        MTextField {
            text: Config.network?.mirrorCountry ?? ""
            onAccepted: ConfigWrite.set("network.mirrorCountry", text)
        }
    }
}
