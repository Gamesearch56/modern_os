import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Model { id: dockModel }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.dock.enable"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: DockLayout.enabled
            onToggled: (v) => {
                DockLayout.liveEnabled = v ? 1 : 0;
                ConfigWrite.set("dock.enabled", v);
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.dockAutoHide"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: DockLayout.autoHide
            onToggled: (v) => {
                DockLayout.liveAutoHide = v ? 1 : 0;
                ConfigWrite.set("dock.autoHide", v);
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.dockShowNames"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: DockLayout.showNames
            onToggled: (v) => {
                DockLayout.liveShowNames = v ? 1 : 0;
                ConfigWrite.set("dock.showNames", v);
            }
        }
    }

    MField {
        labelKey: "settings.fields.dockTheme"
        MSelect {
            Layout.fillWidth: true
            value: DockLayout.theme
            model: [
                { value: "beam", titleKey: "settings.dock.beam" },
                { value: "inventory", titleKey: "settings.dock.inventory" },
                { value: "floating", titleKey: "settings.dock.floating" }
            ]
            onSelected: (v) => {
                DockLayout.liveTheme = v;
                ConfigWrite.set("dock.theme", v);
            }
        }
    }

    MField {
        labelKey: "settings.fields.dockHover"
        MSelect {
            Layout.fillWidth: true
            value: DockLayout.hover
            model: [
                { value: "zoom", titleKey: "settings.dock.hoverZoom" },
                { value: "color", titleKey: "settings.dock.hoverColor" },
                { value: "bounce", titleKey: "settings.dock.hoverBounce" },
                { value: "lift", titleKey: "settings.dock.hoverLift" },
                { value: "none", titleKey: "settings.dock.hoverNone" }
            ]
            onSelected: (v) => {
                DockLayout.liveHover = v;
                ConfigWrite.set("dock.hover", v);
            }
        }
    }

    MField {
        labelKey: "settings.fields.dockIconSize"
        MSlider {
            from: Tokens.icon.md
            to: Tokens.spacing.xxl * 3
            value: DockLayout.iconSize
            showValue: true
            onMoved: (v) => { DockLayout.liveIconSize = Math.round(v); }
            onCommitted: (v) => ConfigWrite.set("dock.iconSize", Math.round(v))
        }
    }

    MField {
        labelKey: "settings.fields.dockPad"
        MSlider {
            from: 0
            to: Tokens.spacing.xxl
            value: DockLayout.pad
            showValue: true
            onMoved: (v) => { DockLayout.livePad = Math.round(v); }
            onCommitted: (v) => ConfigWrite.set("dock.pad", Math.round(v))
        }
    }

    MField {
        labelKey: "settings.fields.dockGap"
        MSlider {
            from: 0
            to: Tokens.spacing.xxl
            value: DockLayout.gap
            showValue: true
            onMoved: (v) => { DockLayout.liveGap = Math.round(v); }
            onCommitted: (v) => ConfigWrite.set("dock.gap", Math.round(v))
        }
    }

    DockBoard {
        Layout.fillWidth: true
        pins: dockModel.pins
        installed: dockModel.installed
    }
}
