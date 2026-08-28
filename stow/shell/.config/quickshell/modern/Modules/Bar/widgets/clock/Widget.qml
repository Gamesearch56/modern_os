import QtQuick
import Quickshell
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

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
        onClicked: Apps.launch("calendar")
    }
}
