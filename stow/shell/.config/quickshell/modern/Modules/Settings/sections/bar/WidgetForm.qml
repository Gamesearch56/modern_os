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
    readonly property bool _volumeScroll: root.widgetId === "audio" || root.widgetId === "media"

    hugContent: true
    cardHeight: root._volumeScroll
        ? Tokens.spacing.xxl * 7
        : (root.widgetId === "clock" ? Tokens.spacing.xxl * 6
            : (root.widgetId === "weather" ? Tokens.spacing.xxl * 9 : Tokens.spacing.xxl * 7))
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
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.md
                spacing: Tokens.spacing.md
                MText {
                    key: "settings.fields.weatherGeo"
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MSwitch {
                    checked: (Config.widgets?.weather?.locationMode || "auto") !== "manual"
                    onToggled: (v) => ConfigWrite.set("widgets.weather.locationMode", v ? "auto" : "manual")
                }
            }
            MHint {
                key: "settings.hints.weatherLocation"
                Layout.fillWidth: true
            }
            MField {
                visible: (Config.widgets?.weather?.locationMode || "auto") === "manual"
                labelKey: "settings.fields.weatherCity"
                MSelect {
                    remote: true
                    placeholderKey: "settings.weatherSearchCity"
                    value: Config.widgets?.weather?.manualLocation ?? ""
                    valueLabel: Config.widgets?.weather?.placeName ?? ""
                    model: WeatherGeocode.results
                    onSearched: (q) => WeatherGeocode.search(q)
                    onSelected: (v) => {
                        ConfigWrite.set("widgets.weather.manualLocation", v);
                        const lab = WeatherGeocode.labelFor(v);
                        if (lab.length)
                            ConfigWrite.set("widgets.weather.placeName", lab);
                    }
                }
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

        ColumnLayout {
            visible: root._volumeScroll
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spacing.sm

            MField {
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
}
