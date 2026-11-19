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
    readonly property string stillsDir: XdgDirs.toTilde(XdgDirs.resolveStills(Config.screenshots.directory))
    readonly property string recordingsDir: XdgDirs.toTilde(XdgDirs.resolveRecordings(Config.screenshots.videoDirectory))

    MSectionHeader {
        key: "settings.screenshots.stills"
        topMargin: 0
    }

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
            onCommitted: (v) => ConfigWrite.set("screenshots.quality", Math.round(v))
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
            path: root.stillsDir
            onBrowse: {
                Settings.close();
                FilePick.pickDirectory(XdgDirs.resolveStills(Config.screenshots.directory),
                    "screenshots", "screenshots.directory");
            }
        }
    }

    MSectionHeader {
        key: "settings.screenshots.video"
        topMargin: Tokens.spacing.xxl
    }

    MField {
        labelKey: "settings.fields.recordAudio"
        headerExtra: MSwitch {
            checked: !!(Config.screenshots.recordAudio)
            onToggled: (v) => ConfigWrite.set("screenshots.recordAudio", v)
        }
    }

    MField {
        labelKey: "settings.fields.videoDir"
        MFolderField {
            path: root.recordingsDir
            onBrowse: {
                Settings.close();
                FilePick.pickDirectory(XdgDirs.resolveRecordings(Config.screenshots.videoDirectory),
                    "screenshots", "screenshots.videoDirectory");
            }
        }
    }
}
