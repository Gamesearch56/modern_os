import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root
    implicitWidth: row.implicitWidth + Tokens.spacing.md
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    readonly property string _icon: Audio.muted ? "audio-volume-muted" : (Audio.volume < 34 ? "audio-volume-low" : (Audio.volume < 67 ? "audio-volume-medium" : "audio-volume-high"))

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.xs

        MIcon {
            name: root._icon
            size: Tokens.spacing.lg
        }

        MText {
            value: Audio.muted ? I18n.t("bar.muted") : (Audio.volume + "%")
            styleName: "labelLarge"
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                Audio.toggleMute();
            else if (mouse.button === Qt.RightButton)
                Audio.cycleSink();
            else
                popup.open = !popup.open;
        }
        onWheel: (w) => {
            const fine = w.modifiers & Qt.ShiftModifier;
            const step = fine ? (Config.widgets.audio?.scrollStepFinePercent ?? 1) : (Config.widgets.audio?.scrollStepPercent ?? 5);
            Audio.adjustVolume(w.angleDelta.y > 0 ? step : -step);
        }
    }

    MPopup {
        id: popup
        open: false
        width: Tokens.spacing.xxl * 8
        height: Tokens.spacing.xxl * 6
        anchors.top: parent.bottom
        anchors.topMargin: Tokens.spacing.sm

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            MText { key: "bar.volume"; styleName: "titleSmall" }

            MSlider {
                Layout.fillWidth: true
                from: 0
                to: Config.audio.masterVolumeLimit ?? 100
                value: Audio.volume
                onMoved: (v) => Audio.setVolume(v)
            }

            MButton {
                kind: "text"
                key: "bar.soundSettings"
                onClicked: {
                    popup.open = false;
                    Settings.openAt("audio", "");
                }
            }
        }
    }
}
