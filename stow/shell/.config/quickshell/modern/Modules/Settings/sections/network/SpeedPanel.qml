import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.sm

    readonly property var stats: {
        void Network.speedMbps;
        void Network.speedBytes;
        void Network.speedSeconds;
        void Network.speedDnsMs;
        void Network.speedConnectMs;
        void Network.speedHttp;
        return [
            { labelKey: "settings.network.speedDownload", valueKey: "settings.speedTestResult", params: ({ n: Network.speedMbps.toFixed(1) }) },
            { labelKey: "settings.network.speedTransferred", valueKey: "settings.network.mb", params: ({ n: (Network.speedBytes / 1000000).toFixed(1) }) },
            { labelKey: "settings.network.speedTime", valueKey: "settings.network.seconds", params: ({ n: Network.speedSeconds.toFixed(1) }) },
            { labelKey: "settings.network.speedDns", valueKey: "settings.network.ms", params: ({ n: String(Math.round(Network.speedDnsMs)) }) },
            { labelKey: "settings.network.speedConnect", valueKey: "settings.network.ms", params: ({ n: String(Math.round(Network.speedConnectMs)) }) },
            { labelKey: "settings.network.speedHttp", valueKey: "settings.network.httpCode", params: ({ n: String(Network.speedHttp) }) }
        ];
    }

    MSectionHeader {
        key: "settings.fields.speedTest"
        hintKey: "settings.hints.speedTest"
        topMargin: Tokens.spacing.xxl
    }

    MButton {
        kind: "filled"
        key: "settings.speedTestRun"
        fillWidth: true
        enabled: !Network.speedTesting
        onClicked: Network.speedTest()
    }

    MLinearProgress {
        visible: Network.speedTesting
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.sm
        indeterminate: true
    }

    MText {
        visible: Network.speedFailed && !Network.speedTesting
        key: "settings.network.speedFailed"
        styleName: "bodyMedium"
        color: Colors.color.error
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    GridLayout {
        visible: Network.speedDone && !Network.speedFailed
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.md
        columns: 2
        columnSpacing: Tokens.spacing.xl
        rowSpacing: Tokens.spacing.xl

        Repeater {
            model: root.stats.length
            ColumnLayout {
                required property int index
                readonly property var stat: root.stats[index]
                Layout.fillWidth: true
                spacing: Tokens.spacing.xs
                MText {
                    key: stat.labelKey
                    styleName: "titleSmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MText {
                    key: stat.valueKey
                    params: stat.params
                    styleName: "headlineSmall"
                    Layout.fillWidth: true
                }
            }
        }
    }
}
