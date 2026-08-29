import QtQuick
import Quickshell
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: label.implicitWidth + Tokens.spacing.md * 2
    implicitHeight: Config.bar.height

    SystemClock {
        id: clock
        precision: (Config.widgets.clock?.showSeconds ?? false) ? SystemClock.Seconds : SystemClock.Minutes
    }

    BarIslandHit {
        checked: popup.open
        onClicked: popup.open = !popup.open
    }

    MText {
        id: label
        anchors.centerIn: parent
        z: 1
        value: DateTime.clockLabel(
            clock.date,
            Config.language.dateFormat || "DD.MM.YYYY",
            Config.language.timeFormat || "HH:mm",
            Config.widgets.clock?.showSeconds ?? false,
            Config.widgets.clock?.showWeekday ?? false)
        styleName: "labelLarge"
        color: popup.open ? Colors.color.onPrimaryContainer : Colors.color.onSurface
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        implicitWidth: Tokens.spacing.xxl * 12
        implicitHeight: Tokens.spacing.xxl * 12
        hAlign: Qt.AlignHCenter

        BarPanelChrome {
            anchors.fill: parent
            titleKey: "calendar.title"

            MPane {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    anchors.fill: parent
                    clip: true
                    model: Calendar.events.length

                    delegate: MListItem {
                        required property int index
                        readonly property var row: Calendar.events[index] || ({})
                        width: ListView.view.width
                        titleValue: row.summary || ""
                        subtitleValue: row.when || ""
                    }

                    MEmptyState {
                        visible: Calendar.events.length === 0
                        anchors.fill: parent
                        iconName: "x-office-calendar-symbolic"
                        titleKey: "calendar.empty"
                    }
                }
            }

            MButton {
                kind: "filled"
                key: "calendar.open"
                fillWidth: true
                onClicked: {
                    popup.open = false;
                    if (!Apps.launch("calendar"))
                        Settings.openAt("applications", "");
                }
            }
        }
    }
}
