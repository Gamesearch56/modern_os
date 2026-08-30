import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    MText {
        Layout.fillWidth: true
        styleName: "titleLarge"
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        value: {
            void clock.date;
            void Config.language.dateFormat;
            void Config.language.timeFormat;
            return DateTime.clockLabel(
                DateTime.displayDate(clock.date),
                Config.language.dateFormat || "DD.MM.YYYY",
                Config.language.timeFormat || "HH:mm",
                false,
                false);
        }
    }

    MField {
        labelKey: "settings.fields.languageUi"
        MSegmented {
            value: Config.language.ui || "de"
            model: [
                { value: "en", titleKey: "settings.langEn" },
                { value: "de", titleKey: "settings.langDe" }
            ]
            onSelected: (v) => ConfigWrite.set("language.ui", v)
        }
    }

    MField {
        labelKey: "settings.fields.firstDayOfWeek"
        MSegmented {
            value: Config.language.firstDayOfWeek
            model: [
                { value: 1, titleKey: "settings.weekMon" },
                { value: 0, titleKey: "settings.weekSun" }
            ]
            onSelected: (v) => ConfigWrite.set("language.firstDayOfWeek", Number(v))
        }
    }

    MField {
        labelKey: "settings.fields.dateFormat"
        MSelect {
            value: Config.language.dateFormat || "DD.MM.YYYY"
            model: [
                { value: "DD.MM.YYYY", titleValue: "DD.MM.YYYY" },
                { value: "YYYY-MM-DD", titleValue: "YYYY-MM-DD" },
                { value: "MM/DD/YYYY", titleValue: "MM/DD/YYYY" }
            ]
            onSelected: (v) => ConfigWrite.set("language.dateFormat", v)
        }
    }

    MField {
        labelKey: "settings.fields.timeFormat"
        MSelect {
            value: Config.language.timeFormat || "HH:mm"
            model: [
                { value: "HH:mm", titleValue: "HH:mm" },
                { value: "hh:mm a", titleValue: "hh:mm a" }
            ]
            onSelected: (v) => ConfigWrite.set("language.timeFormat", v)
        }
    }
}
