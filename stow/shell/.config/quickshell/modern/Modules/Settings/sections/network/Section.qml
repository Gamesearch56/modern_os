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
        value: Network.rxMbps.toFixed(1) + " / " + Network.txMbps.toFixed(1) + " Mbps"
        styleName: "labelLarge"
    }
    Row {
        Layout.fillWidth: true
        spacing: 2
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
            text: Config.network?.mirrorCountry || "Germany"
            onAccepted: ConfigWrite.set("network.mirrorCountry", text)
        }
    }
}
