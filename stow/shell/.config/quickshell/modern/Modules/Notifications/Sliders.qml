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
            wheel: true
            onMoved: (v) => Audio.setVolume(v)
        }
    }

    MField {
        visible: Brightness.available
        labelKey: "quickSettings.brightness"
        MSlider {
            enabled: Brightness.available && !Brightness.setting
            from: 1
            to: 100
            value: Brightness.percent
            showValue: true
            wheel: true
            onMoved: (v) => Brightness.setPercent(v)
        }
    }
}
