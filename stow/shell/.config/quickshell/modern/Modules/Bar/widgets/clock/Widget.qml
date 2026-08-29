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
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    SystemClock {
        id: clock
        precision: (Config.widgets.clock?.showSeconds ?? false) ? SystemClock.Seconds : SystemClock.Minutes
    }

    MText {
        id: label
        anchors.centerIn: parent
        value: DateTime.clockLabel(
            clock.date,
            Config.language.dateFormat || "DD.MM.YYYY",
            Config.language.timeFormat || "HH:mm",
            Config.widgets.clock?.showSeconds ?? false,
            Config.widgets.clock?.showWeekday ?? false)
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.open = !popup.open
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        implicitWidth: Tokens.spacing.xxl * 12
        implicitHeight: Tokens.spacing.xxl * 12
        hAlign: Qt.AlignHCenter

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.sm

            MText {
                key: "calendar.title"
                styleName: "headlineSmall"
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                    iconName: "office-calendar"
                    titleKey: "calendar.empty"
                }
            }

            MButton {
                kind: "filled"
                key: "calendar.open"
                fillWidth: true
                onClicked: {
                    popup.open = false;
                    Apps.launch("calendar");
                }
            }
        }
    }
}
