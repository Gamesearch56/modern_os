import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.activeProfile" }
    MSelect {
        Layout.fillWidth: true
        value: Config.design.activeProfile
        model: [
            { value: "expressive-dark", titleKey: "settings.themes.expressive" },
            { value: "tonal-spot-dark", titleKey: "settings.themes.tonalSpot" },
            { value: "tonal-spot-auto", titleKey: "settings.themes.tonalSpotAuto" },
            { value: "fidelity-high-contrast", titleKey: "settings.themes.fidelity" },
            { value: "monochrome-dark", titleKey: "settings.themes.monochrome" }
        ]
        onSelected: (v) => ConfigWrite.set("design.activeProfile", v)
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
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip { key: "settings.motionOff"; checked: Config.motion.scale === 0; onClicked: ConfigWrite.set("motion.scale", 0) }
        MChip { key: "settings.motionDefault"; checked: Config.motion.scale === 1; onClicked: ConfigWrite.set("motion.scale", 1) }
        MChip { key: "settings.motionSlow"; checked: Config.motion.scale === 1.5; onClicked: ConfigWrite.set("motion.scale", 1.5) }
    }
    MHint { key: "settings.hints.overlayMotion"; Layout.fillWidth: true }
    RowLayout {
        spacing: Tokens.spacing.sm
        MChip { key: "settings.overlayFade"; checked: Config.motion.overlay === "fade"; onClicked: ConfigWrite.set("motion.overlay", "fade") }
        MChip { key: "settings.overlayZoom"; checked: Config.motion.overlay === "zoom"; onClicked: ConfigWrite.set("motion.overlay", "zoom") }
        MChip { key: "settings.overlayBoth"; checked: (Config.motion.overlay || "fadeZoom") === "fadeZoom"; onClicked: ConfigWrite.set("motion.overlay", "fadeZoom") }
    }

    MSectionHeader { key: "settings.fields.boot" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.wallpaperOnLock"
        MSwitch {
            checked: Config.design.bootScreen.wallpaperOnLock
            onToggled: (v) => ConfigWrite.set("design.bootScreen.wallpaperOnLock", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.wallpaperOnVivaldi"
        MSwitch {
            checked: Config.design.bootScreen.wallpaperOnVivaldi
            onToggled: (v) => ConfigWrite.set("design.bootScreen.wallpaperOnVivaldi", v)
        }
    }
}
