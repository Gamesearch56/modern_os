import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader {
        key: "diagnostics.software"
        topMargin: 0
    }
    FactRow {
        labelKey: "settings.overview.os"
        value: Diagnostics.os
    }
    FactRow {
        labelKey: "settings.overview.kernel"
        value: Diagnostics.kernel
    }
    FactRow {
        labelKey: "settings.overview.session"
        value: I18n.t("settings.overview.wayland")
    }
    FactRow {
        labelKey: "settings.overview.wm"
        value: Diagnostics.wm
    }
    FactRow {
        labelKey: "settings.overview.shell"
        value: Diagnostics.shell
    }
    FactRow {
        labelKey: "settings.overview.launcher"
        value: I18n.t("settings.overview.launcherName")
    }
    FactRow {
        labelKey: "settings.fields.fileManager"
        value: Apps.displayName("fileManager")
    }
    FactRow {
        labelKey: "settings.fields.videoPlayer"
        value: Apps.displayName("videoPlayer")
    }
    FactRow {
        labelKey: "settings.fields.imageViewer"
        value: Apps.displayName("imageViewer")
    }
    FactRow {
        labelKey: "settings.fields.browser"
        value: Apps.displayName("browser")
    }
    FactRow {
        labelKey: "settings.fields.terminal"
        value: Apps.displayName("terminal")
    }

    MSectionHeader {
        key: "diagnostics.hardware"
        topMargin: Tokens.spacing.xxl
    }
    FactRow {
        labelKey: "settings.overview.cpu"
        value: Diagnostics.cpu
    }
    FactRow {
        labelKey: "settings.overview.gpu"
        value: Diagnostics.gpu
    }
    FactRow {
        labelKey: "settings.overview.memory"
        value: Diagnostics.memory
    }
    FactRow {
        labelKey: "settings.overview.board"
        value: Diagnostics.board
    }
    FactRow {
        labelKey: "settings.overview.disk"
        value: Diagnostics.disk
    }

    MSectionHeader {
        key: "diagnostics.bootTime"
        topMargin: Tokens.spacing.xxl
    }
    MText {
        visible: Diagnostics.bootTotal > 0
        value: Diagnostics.formatSeconds(Diagnostics.bootTotal)
        styleName: "headlineMedium"
        Layout.fillWidth: true
    }
    MText {
        key: "settings.overview.bootFinished"
        styleName: "bodySmall"
        color: Colors.color.onSurfaceVariant
        Layout.fillWidth: true
    }
    Repeater {
        model: Diagnostics.bootStages.length
        ColumnLayout {
            required property int index
            readonly property var stage: Diagnostics.bootStages[index] || ({})
            spacing: Tokens.spacing.xs
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                MText {
                    key: "settings.overview." + (stage.id || "")
                    styleName: "bodyMedium"
                    Layout.fillWidth: true
                }
                MText {
                    value: Diagnostics.formatSeconds(stage.seconds)
                    styleName: "labelLarge"
                    familyRole: "monospace"
                }
            }
            MLinearProgress {
                Layout.fillWidth: true
                value: Diagnostics.bootTotal > 0
                    ? Number(stage.seconds || 0) / Diagnostics.bootTotal
                    : 0
            }
        }
    }
}
