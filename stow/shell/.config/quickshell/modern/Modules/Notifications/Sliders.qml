import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    Layout.fillWidth: true
    Layout.topMargin: Tokens.spacing.sm
    Layout.bottomMargin: Tokens.spacing.sm
    spacing: Tokens.spacing.lg

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
        labelKey: "quickSettings.brightness"
        hintKey: Brightness.available ? "" : "quickSettings.brightnessUnavailable"
        MSlider {
            enabled: Brightness.available
            from: 1
            to: 100
            value: Brightness.percent
            showValue: true
            onMoved: (v) => Brightness.setPercent(v)
        }
    }
}
