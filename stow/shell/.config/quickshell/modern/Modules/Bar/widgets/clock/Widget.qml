import QtQuick
import Quickshell
import "../../../../Commons"
import "../../../../Widgets"

Rectangle {
    id: root
    radius: Tokens.radius.full
    color: Colors.color.surfaceContainerHighest
    implicitWidth: label.implicitWidth + Tokens.spacing.md * 2
    implicitHeight: Tokens.spacing.xl + Tokens.spacing.xs

    SystemClock {
        id: clock
        precision: (Config.widgets.clock?.showSeconds ?? false) ? SystemClock.Seconds : SystemClock.Minutes
    }

    MText {
        id: label
        anchors.centerIn: parent
        value: root._format(clock.date)
        styleName: "labelLarge"
    }

    MouseArea {
        anchors.fill: parent
        // Calendar panel is Modules/Panels; click is reserved for that
        // once the panel module is loaded. For M0 this is display-only.
    }

    function _pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function _format(d: var): string {
        if (!d)
            return "";
        const dateStr = root._pad(d.getDate()) + "." + root._pad(d.getMonth() + 1) + "." + d.getFullYear();
        let timeStr = root._pad(d.getHours()) + ":" + root._pad(d.getMinutes());
        if (Config.widgets.clock?.showSeconds)
            timeStr += ":" + root._pad(d.getSeconds());
        return dateStr + " - " + timeStr;
    }
}
