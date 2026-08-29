import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.languageUi" }
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip {
            key: "settings.langEn"
            checked: Config.language.ui === "en"
            onClicked: ConfigWrite.set("language.ui", "en")
        }
        MChip {
            key: "settings.langDe"
            checked: Config.language.ui === "de"
            onClicked: ConfigWrite.set("language.ui", "de")
        }
    }

    MSectionHeader { key: "settings.fields.dateFormat" }
    MSelect {
        Layout.fillWidth: true
        value: Config.language.dateFormat
        model: [
            { value: "DD.MM.YYYY", titleValue: "DD.MM.YYYY" },
            { value: "YYYY-MM-DD", titleValue: "YYYY-MM-DD" },
            { value: "MM/DD/YYYY", titleValue: "MM/DD/YYYY" }
        ]
        onSelected: (v) => ConfigWrite.set("language.dateFormat", v)
    }

    MSectionHeader { key: "settings.fields.timeFormat" }
    MSelect {
        Layout.fillWidth: true
        value: Config.language.timeFormat
        model: [
            { value: "HH:mm", titleValue: "HH:mm" },
            { value: "hh:mm a", titleValue: "hh:mm a" }
        ]
        onSelected: (v) => ConfigWrite.set("language.timeFormat", v)
    }

    MSectionHeader { key: "settings.fields.firstDayOfWeek" }
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip {
            key: "settings.weekMon"
            checked: Config.language.firstDayOfWeek === 1
            onClicked: ConfigWrite.set("language.firstDayOfWeek", 1)
        }
        MChip {
            key: "settings.weekSun"
            checked: Config.language.firstDayOfWeek === 0
            onClicked: ConfigWrite.set("language.firstDayOfWeek", 0)
        }
    }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.showWeekday"
        MSwitch {
            checked: !!(Config.widgets?.clock?.showWeekday)
            onToggled: (v) => ConfigWrite.set("widgets.clock.showWeekday", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.showSeconds"
        MSwitch {
            checked: !!(Config.widgets?.clock?.showSeconds)
            onToggled: (v) => ConfigWrite.set("widgets.clock.showSeconds", v)
        }
    }

    MField {
        labelKey: "settings.fields.timezone"
        hintKey: "settings.hints.timezone"
        MTextField {
            text: Locale.timezone || Config.language.timezone || ""
            onAccepted: {
                ConfigWrite.set("language.timezone", text);
                Locale.setTimezone(text);
            }
        }
    }
    MField {
        labelKey: "settings.fields.previewDate"
        hintKey: "settings.hints.previewDate"
        MTextField {
            text: Config.language.previewDate ?? ""
            placeholderKey: "settings.previewDatePlaceholder"
            onAccepted: ConfigWrite.set("language.previewDate", text)
        }
    }
}
