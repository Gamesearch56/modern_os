import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.barLeft" }
    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        Repeater {
            model: Config.bar.left
            MChip {
                required property var modelData
                key: "bar." + modelData
            }
        }
    }
    MSectionHeader { key: "settings.fields.barCenter" }
    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        Repeater {
            model: Config.bar.center
            MChip {
                required property var modelData
                key: "bar." + modelData
            }
        }
    }
    MSectionHeader { key: "settings.fields.barRight" }
    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        Repeater {
            model: Config.bar.right
            MChip {
                required property var modelData
                key: "bar." + modelData
            }
        }
    }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.showSeconds"
        MSwitch {
            checked: !!(Config.widgets.clock?.showSeconds)
            onToggled: (v) => ConfigWrite.set("widgets.clock.showSeconds", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.showWeekday"
        MSwitch {
            checked: !!(Config.widgets.clock?.showWeekday)
            onToggled: (v) => ConfigWrite.set("widgets.clock.showWeekday", v)
        }
    }

    MField {
        labelKey: "settings.fields.weatherLocation"
        hintKey: "settings.hints.weatherLocation"
        MTextField {
            text: Config.widgets.weather?.manualLocation || ""
            placeholderKey: "settings.weatherLocationPlaceholder"
            onAccepted: ConfigWrite.set("widgets.weather.manualLocation", text)
        }
    }
}
