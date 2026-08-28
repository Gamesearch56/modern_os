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
}
