import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MHint {
        key: "settings.hints.screenshotDir"
        params: ({ dir: Config.screenshots.directory || "" })
        Layout.fillWidth: true
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.copyClipboard"
        MSwitch {
            checked: Config.screenshots.copyToClipboard
            onToggled: (v) => ConfigWrite.set("screenshots.copyToClipboard", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.openEditor"
        MSwitch {
            checked: Config.screenshots.openEditorAfterCapture
            onToggled: (v) => ConfigWrite.set("screenshots.openEditorAfterCapture", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.includeCursor"
        MSwitch {
            checked: Config.screenshots.includeCursor
            onToggled: (v) => ConfigWrite.set("screenshots.includeCursor", v)
        }
    }
}
