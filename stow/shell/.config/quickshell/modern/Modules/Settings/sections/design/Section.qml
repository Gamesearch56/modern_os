import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property bool createOpen: false
    property string newName: ""

    Connections {
        target: Theme
        function onCreated(path) {
            Notifications.toast(I18n.t("settings.themeCreated"), path);
        }
    }

    MSectionHeader { key: "settings.fields.activeProfile" }
    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm
        Repeater {
            model: Theme.slugs
            Rectangle {
                required property var modelData
                width: Tokens.spacing.xxl * 5
                height: Tokens.spacing.xxl * 3
                radius: Tokens.radius.medium
                color: String(modelData) === Config.design.activeProfile ? Colors.color.primary : Colors.color.surfaceContainerHighest
                border.width: 1
                border.color: Colors.color.outlineVariant

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.sm
                    MText {
                        value: String(modelData)
                        styleName: "labelLarge"
                        color: String(modelData) === Config.design.activeProfile ? Colors.color.onPrimary : Colors.color.onSurface
                    }
                    Row {
                        spacing: Tokens.spacing.xs
                        Repeater {
                            model: [Colors.color.primary, Colors.color.secondary, Colors.color.tertiary]
                            Rectangle {
                                required property var modelData
                                width: Tokens.spacing.md
                                height: Tokens.spacing.md
                                radius: Tokens.radius.full
                                color: modelData
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ConfigWrite.set("design.activeProfile", modelData)
                }
            }
        }
        MIconButton {
            iconName: "list-add"
            onClicked: root.createOpen = true
        }
    }

    MDialog {
        anchors.fill: parent
        open: root.createOpen
        titleKey: "settings.themeCreate"
        confirmKey: "settings.save"
        onConfirmed: {
            Theme.create(root.newName);
            root.newName = "";
            root.createOpen = false;
        }
        onCancelled: {
            root.newName = "";
            root.createOpen = false;
        }
        MTextField {
            placeholderKey: "settings.themeName"
            onTextEdited: root.newName = text
        }
    }

    MSectionHeader { key: "settings.fields.typeScale" }
    MSlider {
        Layout.fillWidth: true
        from: 0.8
        to: 1.4
        value: Config.typography.scale
        showValue: true
        onMoved: (v) => ConfigWrite.set("typography.scale", Math.round(v * 100) / 100)
    }
    MText {
        key: "settings.typePreview"
        styleName: "headlineSmall"
    }
    MText {
        key: "settings.typePreviewBody"
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    MSectionHeader { key: "settings.fields.chrome" }
    MField {
        labelKey: "settings.fields.transparency"
        MSlider {
            from: 0.4
            to: 1
            value: Config.design.transparency
            onMoved: (v) => ConfigWrite.set("design.transparency", Math.round(v * 100) / 100)
        }
    }
    MField {
        labelKey: "settings.fields.cornerRounding"
        MSlider {
            from: 0.5
            to: 1.5
            value: Config.design.cornerRounding
            onMoved: (v) => ConfigWrite.set("design.cornerRounding", Math.round(v * 100) / 100)
        }
    }

    MSectionHeader {
        key: "settings.fields.wallpaperColor"
        hintKey: "settings.hints.surfaceTint"
    }
    MSlider {
        Layout.fillWidth: true
        from: 0.5
        to: 2
        value: Config.design.surfaceTint ?? 1
        onMoved: (v) => ConfigWrite.set("design.surfaceTint", Math.round(v * 10) / 10)
    }

    MSectionHeader {
        key: "settings.fields.animations"
        hintKey: "settings.hints.animations"
    }
    MSegmented {
        Layout.fillWidth: true
        value: String(Config.motion.scale)
        model: [
            { value: "0", titleKey: "settings.motionOff" },
            { value: "1", titleKey: "settings.motionDefault" },
            { value: "1.5", titleKey: "settings.motionSlow" }
        ]
        onSelected: (v) => ConfigWrite.set("motion.scale", Number(v))
    }
    MSegmented {
        Layout.fillWidth: true
        value: Config.motion.overlay || "fadeZoom"
        model: [
            { value: "fade", titleKey: "settings.overlayFade" },
            { value: "zoom", titleKey: "settings.overlayZoom" },
            { value: "fadeZoom", titleKey: "settings.overlayBoth" }
        ]
        onSelected: (v) => ConfigWrite.set("motion.overlay", v)
    }
}
