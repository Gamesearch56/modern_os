import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.md

    MField {
        labelKey: "bar.volume"
        MSlider {
            from: 0
            to: Config.audio.masterVolumeLimit ?? 100
            value: Audio.volume
            showValue: true
            onMoved: (v) => Audio.setVolume(v)
        }
    }

    MField {
        visible: Brightness.available
        labelKey: "quickSettings.brightness"
        MSlider {
            enabled: Brightness.available
            from: 1
            to: 100
            value: Brightness.percent
            onMoved: (v) => Brightness.setPercent(v)
        }
    }
}
