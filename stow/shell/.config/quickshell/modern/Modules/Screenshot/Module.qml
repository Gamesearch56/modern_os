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

    Connections {
        target: Recording
        function onSaved(path) {
            Notifications.toast(
                I18n.t("recording.saved"),
                I18n.t("recording.savedHint"),
                path
            );
        }
        function onFailed() {
            Notifications.toast(I18n.t("recording.failed"), "");
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: Recording.active
        onActivated: Recording.stop()
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: hudLoader
            required property var modelData
            active: Screenshot.hudOpen && !Recording.active

            Hud {
                screen: hudLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: recLoader
            required property var modelData
            active: Recording.active

            RecordingBar {
                screen: recLoader.modelData
            }
        }
    }
}
