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
                const id = (e && (e.id || e.name)) || Apps.desktopId("calendar");
                if (!Hypr.raiseDesktop(String(id || "")) && !Apps.launch("calendar"))
                    Settings.openAt("accounts", "calendar");
            }
        }
    }
}
