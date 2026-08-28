import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../Commons"
import "../../Widgets"
import "../../Services"

RowLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.sm

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        MText {
            value: DateTime.formatTime(clock.date, Config.language.timeFormat || "HH:mm", false)
            styleName: "headlineSmall"
        }
        MText {
            value: DateTime.formatDate(clock.date, Config.language.dateFormat || "DD.MM.YYYY")
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
        }
    }

    MIconButton {
        iconName: "preferences-system"
        onClicked: {
            Notifications.hide();
            Settings.openAt("general", "");
        }
    }
    MIconButton {
        iconName: "system-shutdown"
        onClicked: PowerMenu.toggle()
    }
}
