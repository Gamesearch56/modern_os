import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    width: parent ? parent.width : Tokens.spacing.xxl * 14
    implicitWidth: Tokens.spacing.xxl * 14
    implicitHeight: chrome.implicitHeight

    property string range: "month"

    BarPanelChrome {
        id: chrome
        width: root.width
        titleKey: "calendar.title"

        actions: MIconButton {
            iconName: "view-refresh-symbolic"
            key: "calendar.refresh"
            busy: Calendar.busy
            onClicked: Calendar.refresh()
        }

        MSegmented {
            Layout.fillWidth: true
            value: root.range
            model: [
                { value: "month", titleKey: "calendar.monthTab" },
                { value: "events", titleKey: "calendar.eventsTab" }
            ]
            onSelected: (v) => root.range = String(v)
        }

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: item ? item.implicitHeight : Tokens.spacing.xxl * 8
            source: Qt.resolvedUrl(root.range === "events" ? "EventsList.qml" : "MonthGrid.qml")
        }

        MButton {
            kind: "filled"
            key: "calendar.open"
            fillWidth: true
            onClicked: {
                const e = Apps.entryFor("calendar");
                const id = String((e && (e.id || e.name)) || Apps.desktopId("calendar") || "");
                if (!id.length || !Hypr.raiseDesktopOrLaunch(id, e)) {
                    Notifications.toast(I18n.t("calendar.needApp"), "");
                    Settings.openAt("applications", "calendar");
                }
                Popups.dismiss();
            }
        }
    }
}
