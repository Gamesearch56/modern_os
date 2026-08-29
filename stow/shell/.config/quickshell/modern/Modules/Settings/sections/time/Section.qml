import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.md
    MHint {
        key: "settings.hints.timeMerged"
        Layout.fillWidth: true
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
}
