import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.xs

    MText {
        key: "bar.volume"
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
    }
    MSlider {
        Layout.fillWidth: true
        from: 0
        to: Config.audio.masterVolumeLimit ?? 100
        value: Audio.volume
        showValue: true
        onMoved: (v) => Audio.setVolume(v)
    }

    MText {
        visible: Brightness.available
        key: "quickSettings.brightness"
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
    }
    MSlider {
        visible: Brightness.available
        Layout.fillWidth: true
        enabled: Brightness.available
        from: 1
        to: 100
        value: Brightness.percent
        onMoved: (v) => Brightness.setPercent(v)
    }
}
