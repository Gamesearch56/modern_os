import QtQuick
import Quickshell
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    implicitWidth: BarLayout.vertical ? Config.bar.height : (label.implicitWidth + Tokens.spacing.md * 2)
    implicitHeight: Config.bar.height

    readonly property color _fg: popup.open ? Colors.color.onPrimaryContainer : Colors.color.onSurface

    SystemClock {
        id: clock
        precision: (Config.widgets.clock?.showSeconds ?? false) ? SystemClock.Seconds : SystemClock.Minutes
    }

    BarIslandHit {
        checked: popup.open
        onClicked: popup.open = !popup.open
    }

    MIcon {
        visible: BarLayout.vertical
        anchors.centerIn: parent
        z: 1
        name: "preferences-system-time-symbolic"
        size: Tokens.icon.md
        color: root._fg
    }

    MText {
        id: label
        visible: !BarLayout.vertical
        anchors.centerIn: parent
        z: 1
        value: {
            void Config.widgets.clock.showSeconds;
            void Config.widgets.clock.showWeekday;
            void clock.date;
            return DateTime.clockLabel(
                DateTime.displayDate(clock.date),
                Config.language.dateFormat || "DD.MM.YYYY",
                Config.language.timeFormat || "HH:mm",
                Config.widgets.clock?.showSeconds ?? false,
                Config.widgets.clock?.showWeekday ?? false);
        }
        styleName: "labelLarge"
        color: root._fg
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        implicitWidth: Tokens.spacing.xxl * 14
        implicitHeight: (panelLoader.item ? panelLoader.item.implicitHeight : Tokens.spacing.xxl * 12) + Tokens.spacing.md * 2
        hAlign: Qt.AlignHCenter
        onOpenChanged: {
            Calendar.watching = popup.open;
            if (popup.open) {
                Calendar.resetView();
                Calendar.refresh();
            }
        }

        Loader {
            id: panelLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: item ? item.implicitHeight : parent.height
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                if (item)
                    item.width = Qt.binding(() => panelLoader.width);
            }
        }
    }
}
