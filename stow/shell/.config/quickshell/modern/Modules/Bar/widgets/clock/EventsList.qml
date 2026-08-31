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
        color: "transparent"

            ListView {
                anchors.fill: parent
                clip: true
                model: Calendar.todayEvents.length
                visible: Calendar.todayEvents.length > 0

                delegate: MListItem {
                    required property int index
                    readonly property var ev: (Calendar.todayEvents || [])[index] || ({})
                    width: ListView.view.width
                    titleValue: ev.summary || ""
                    subtitleValue: ev.when || ev.ymd || ""
                    hoverHighlight: false
                }
            }

        MEmptyState {
            visible: Calendar.todayEvents.length === 0 && !Calendar.busy
            anchors.fill: parent
            iconName: "x-office-calendar-symbolic"
            titleKey: "calendar.empty"
            actionKey: Calendar.icsUrl.length === 0 ? "calendar.setupFeed" : ""
            onActionClicked: {
                Settings.openAt("privacy", "calendar");
                Popups.dismiss();
            }
        }
    }
}
