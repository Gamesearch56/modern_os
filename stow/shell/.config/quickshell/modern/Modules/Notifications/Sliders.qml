import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property string monitorDesc: ""

    readonly property bool _canBright: {
        void Brightness.displays;
        void Brightness.listReady;
        return root.monitorDesc.length > 0 && Brightness.canAdjust(root.monitorDesc);
    }

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
        visible: root._canBright
        labelKey: "quickSettings.brightness"
        MSlider {
            enabled: root._canBright && !Brightness.setting
            from: 1
            to: 100
            value: Brightness.percentFor(root.monitorDesc)
            showValue: true
            wheel: true
            onMoved: (v) => Brightness.setFor(root.monitorDesc, Math.round(v))
        }
    }
}
