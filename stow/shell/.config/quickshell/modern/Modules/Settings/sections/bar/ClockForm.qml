import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    RowLayout {
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

    CalendarConnect {
        Layout.fillWidth: true
    }
}
