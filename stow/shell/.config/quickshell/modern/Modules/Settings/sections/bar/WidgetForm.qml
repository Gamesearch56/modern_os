import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MOverlay {
    id: root
    property string widgetId: ""
    open: widgetId.length > 0
    titleKey: {
        if (root.widgetId === "calendar")
            return "calendar.title";
        if (root.widgetId === "ai")
            return "ai.title";
        return "bar." + root.widgetId;
    }
    cardHeight: Tokens.spacing.xxl * 12
    onClosed: {}

    ColumnLayout {
        spacing: Tokens.spacing.md

        MField {
            visible: root.widgetId === "weather"
            labelKey: "settings.fields.weatherLocation"
            hintKey: "settings.hints.weatherLocation"
            MTextField {
                text: Config.widgets?.weather?.manualLocation ?? ""
                placeholderKey: "settings.weatherLocationPlaceholder"
                onAccepted: ConfigWrite.set("widgets.weather.manualLocation", text)
            }
        }
        MSegmented {
            visible: root.widgetId === "weather"
            Layout.fillWidth: true
            value: Config.widgets?.weather?.units ?? "metric"
            model: [
                { value: "metric", titleKey: "settings.weatherMetric" },
                { value: "imperial", titleKey: "settings.weatherImperial" }
            ]
            onSelected: (v) => ConfigWrite.set("widgets.weather.units", v)
        }

        MListItem {
            visible: root.widgetId === "clock"
            Layout.fillWidth: true
            titleKey: "settings.fields.showWeekday"
            MSwitch {
                checked: !!(Config.widgets?.clock?.showWeekday)
                onToggled: (v) => ConfigWrite.set("widgets.clock.showWeekday", v)
            }
        }
        MListItem {
            visible: root.widgetId === "clock"
            Layout.fillWidth: true
            titleKey: "settings.fields.showSeconds"
            MSwitch {
                checked: !!(Config.widgets?.clock?.showSeconds)
                onToggled: (v) => ConfigWrite.set("widgets.clock.showSeconds", v)
            }
        }

        MField {
            visible: root.widgetId === "performance"
            labelKey: "settings.fields.pollInterval"
            MSlider {
                from: 500
                to: 5000
                value: Config.widgets?.performance?.pollIntervalMs ?? 2000
                showValue: true
                onMoved: (v) => ConfigWrite.set("widgets.performance.pollIntervalMs", Math.round(v))
            }
        }
        MListItem {
            visible: root.widgetId === "performance"
            Layout.fillWidth: true
            titleKey: "settings.fields.showGpu"
            MSwitch {
                checked: !!(Config.widgets?.performance?.showGpu)
                onToggled: (v) => ConfigWrite.set("widgets.performance.showGpu", v)
            }
        }
        MListItem {
            visible: root.widgetId === "performance"
            Layout.fillWidth: true
            titleKey: "settings.fields.showTemps"
            MSwitch {
                checked: !!(Config.widgets?.performance?.showTemps)
                onToggled: (v) => ConfigWrite.set("widgets.performance.showTemps", v)
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
                onMoved: (v) => ConfigWrite.set("widgets.audio.scrollStepPercent", Math.round(v))
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
                onMoved: (v) => ConfigWrite.set("widgets.audio.scrollStepFinePercent", Math.round(v))
            }
        }
    }
}
