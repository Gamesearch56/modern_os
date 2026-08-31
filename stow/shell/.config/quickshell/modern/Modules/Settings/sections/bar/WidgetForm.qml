import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MOverlay {
    id: root
    property string widgetId: ""
    open: widgetId.length > 0
    titleKey: root.widgetId === "ai" ? "ai.title" : ("bar." + root.widgetId)
    elevation: 0
    cardColor: Colors.color.surface
    chromeHover: false
    chromeOpacity: 1
    scrimOpacity: Tokens.overlay.lock
    cardWidth: Tokens.spacing.xxl * 14
    cardHeight: root.widgetId === "audio"
        ? Tokens.spacing.xxl * 8
        : (root.widgetId === "clock" ? Tokens.spacing.xxl * 6 : Tokens.spacing.xxl * 7)
    onClosed: {}

    ColumnLayout {
        spacing: Tokens.spacing.md

        ColumnLayout {
            visible: root.widgetId === "weather"
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            MSegmented {
                Layout.fillWidth: true
                value: Config.widgets?.weather?.units ?? "metric"
                model: [
                    { value: "metric", titleKey: "settings.weatherMetric" },
                    { value: "imperial", titleKey: "settings.weatherImperial" }
                ]
                onSelected: (v) => ConfigWrite.set("widgets.weather.units", v)
            }
            MText {
                key: "settings.fields.weatherLocation"
                styleName: "titleSmall"
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.md
            }
            MTextField {
                Layout.fillWidth: true
                text: Config.widgets?.weather?.manualLocation ?? ""
                placeholderKey: "settings.weatherLocationPlaceholder"
                onAccepted: ConfigWrite.set("widgets.weather.manualLocation", text)
                onEditingFinished: ConfigWrite.set("widgets.weather.manualLocation", text)
            }
            MHint {
                key: "settings.hints.weatherLocation"
                Layout.fillWidth: true
            }
        }

        RowLayout {
            visible: root.widgetId === "clock"
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.fields.showWeekday"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MSwitch {
                checked: !!(Config.widgets?.clock?.showWeekday)
                onToggled: (v) => ConfigWrite.set("widgets.clock.showWeekday", v)
            }
        }
        RowLayout {
            visible: root.widgetId === "clock"
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.fields.showSeconds"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MSwitch {
                checked: !!(Config.widgets?.clock?.showSeconds)
                onToggled: (v) => ConfigWrite.set("widgets.clock.showSeconds", v)
            }
        }

        MField {
            visible: root.widgetId === "audio"
            labelKey: "settings.fields.scrollStep"
            MSlider {
                from: 1
                to: 20
                value: Config.widgets?.audio?.scrollStepPercent ?? 5
                showValue: true
                onCommitted: (v) => ConfigWrite.set("widgets.audio.scrollStepPercent", Math.round(v))
            }
        }
        MField {
            visible: root.widgetId === "audio"
            labelKey: "settings.fields.scrollStepFine"
            MSlider {
                from: 1
                to: 5
                value: Config.widgets?.audio?.scrollStepFinePercent ?? 1
                showValue: true
                onCommitted: (v) => ConfigWrite.set("widgets.audio.scrollStepFinePercent", Math.round(v))
            }
        }
    }
}
