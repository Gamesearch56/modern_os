import Quickshell
import QtQuick
import QtQuick.Layouts
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
        spacing: Tokens.spacing.xxs
        Layout.fillWidth: true

        MText {
            value: DateTime.formatTime(clock.date, Config.language.timeFormat || "HH:mm", false)
            styleName: "headlineMedium"
        }

        MText {
            value: DateTime.formatDate(clock.date, Config.language.dateFormat || "DD.MM.YYYY")
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
        }
    }

    MIconButton {
        iconName: "preferences-system-symbolic"
        key: "bar.settings"
        onClicked: {
            Notifications.hide();
            Settings.openAt("general", "");
        }
    }
    MIconButton {
        iconName: "folder-pictures-symbolic"
        key: "wallpaper.title"
        onClicked: {
            Notifications.hide();
            Wallpaper.pick();
        }
    }
    MIconButton {
        iconName: "input-keyboard-symbolic"
        key: "cheatsheet.title"
        onClicked: {
            Notifications.hide();
            Cheatsheet.toggle();
        }
    }
    MIconButton {
        close: true
        iconName: "window-close"
        key: "bar.close"
        onClicked: Notifications.hide()
    }
}
