import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    spacing: Tokens.spacing.sm

    MPane {
        Layout.fillWidth: true
        implicitHeight: Tokens.spacing.xxl * 8

        ListView {
            anchors.fill: parent
            clip: true
            model: Calendar.todayEvents
            visible: Calendar.todayEvents.length > 0

            delegate: MListItem {
                required property var modelData
                width: ListView.view.width
                titleValue: modelData.summary || ""
                subtitleValue: modelData.when || modelData.ymd || ""
            }
        }

        MEmptyState {
            visible: Calendar.todayEvents.length === 0
            anchors.fill: parent
            iconName: "x-office-calendar-symbolic"
            titleKey: "calendar.empty"
            hintKey: Calendar.icsUrl.length === 0 ? "calendar.icsHint" : ""
        }
    }
}
