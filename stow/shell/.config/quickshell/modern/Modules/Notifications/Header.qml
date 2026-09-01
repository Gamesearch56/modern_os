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
        precision: SystemClock.Seconds
    }

    ColumnLayout {
        spacing: Tokens.spacing.xxs

        MText {
            value: DateTime.formatTime(clock.date, Config.language.timeFormat || "HH:mm", true)
            styleName: "headlineMedium"
        }

        MText {
            value: DateTime.formatDate(clock.date, Config.language.dateFormat || "DD.MM.YYYY")
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    RowLayout {
        spacing: Tokens.spacing.xs
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        MIconButton {
            Layout.alignment: Qt.AlignVCenter
            iconName: "input-keyboard-symbolic"
            key: "cheatsheet.title"
            onClicked: {
                Notifications.hide();
                Cheatsheet.toggle();
            }
        }
        MIconButton {
            Layout.alignment: Qt.AlignVCenter
            iconName: "system-software-install-symbolic"
            key: "bar.store"
            onClicked: {
                Notifications.hide();
                Store.show();
            }
        }
        MIconButton {
            Layout.alignment: Qt.AlignVCenter
            iconName: "preferences-system-symbolic"
            key: "bar.settings"
            onClicked: {
                Notifications.hide();
                Settings.openAt("overview", "");
            }
        }
        MIconButton {
            Layout.alignment: Qt.AlignVCenter
            close: true
            iconName: "window-close-symbolic"
            key: "bar.close"
            onClicked: Notifications.hide()
        }
    }
}
