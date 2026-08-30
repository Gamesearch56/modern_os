import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    readonly property string format: Config.screenshots.format || "png"
    readonly property bool lossy: root.format === "jpeg" || root.format === "webp"

    MField {
        labelKey: "settings.fields.screenshotFormat"
        MSegmented {
            value: root.format
            model: [
                { value: "png", titleValue: "PNG" },
                { value: "jpeg", titleValue: "JPEG" },
                { value: "webp", titleValue: "WebP" }
            ]
            onSelected: (v) => ConfigWrite.set("screenshots.format", v)
        }
    }

    MField {
        visible: root.lossy
        labelKey: "settings.fields.screenshotQuality"
        MSlider {
            from: 1
            to: 100
            value: Config.screenshots.quality ?? 90
            showValue: true
            onMoved: (v) => ConfigWrite.set("screenshots.quality", Math.round(v))
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.copyClipboard"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.screenshots.copyToClipboard)
            onToggled: (v) => ConfigWrite.set("screenshots.copyToClipboard", v)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.openEditor"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.screenshots.openEditorAfterCapture)
            onToggled: (v) => ConfigWrite.set("screenshots.openEditorAfterCapture", v)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.includeCursor"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.screenshots.includeCursor)
            onToggled: (v) => ConfigWrite.set("screenshots.includeCursor", v)
        }
    }

    MField {
        labelKey: "settings.fields.screenshotDir"
        MFolderField {
            path: Config.screenshots.directory || ""
            onBrowse: {
                const dir = Config.screenshots.directory || "";
                Settings.close();
                FilePick.pickDirectory(dir, "screenshots");
            }
        }
    }
}
