import Quickshell
import QtQuick
import "../../Commons"
import "../../Services"

Scope {
    Connections {
        target: Screenshot
        function onCaptured(path) {
            const copied = Config.screenshots.copyToClipboard ?? true;
            Notifications.toast(
                I18n.t("screenshot.saved"),
                copied ? I18n.t("screenshot.copied") : I18n.t("screenshot.savedHint"),
                path
            );
        }
    }

    Variants {
        model: Quickshell.screens

        Hud {
            required property var modelData
        }
    }
}
