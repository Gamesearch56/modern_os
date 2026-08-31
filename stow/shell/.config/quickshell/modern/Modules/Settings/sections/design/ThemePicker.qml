import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: Tokens.spacing.md

    readonly property var seed: {
        void Theme.profiles;
        void Theme.pendingSlug;
        void Theme.pendingSpec;
        void Config.design.activeProfile;
        return root._seed();
    }

    readonly property var variantChoices: [
        { value: "tonal-spot", titleKey: "settings.themes.tonalSpot" },
        { value: "expressive", titleKey: "settings.themes.expressive" },
        { value: "vibrant", titleKey: "settings.themes.vibrant" },
        { value: "fidelity", titleKey: "settings.themes.fidelity" },
        { value: "content", titleKey: "settings.themes.content" },
        { value: "fruit-salad", titleKey: "settings.themes.fruitSalad" },
        { value: "rainbow", titleKey: "settings.themes.rainbow" },
        { value: "neutral", titleKey: "settings.themes.neutral" },
        { value: "monochrome", titleKey: "settings.themes.monochrome" }
    ]

    readonly property var modeChoices: [
        { value: "dark", titleKey: "settings.themeModeDark" },
        { value: "light", titleKey: "settings.themeModeLight" }
    ]

    function _activeSlug() {
        const pending = String(Theme.pendingSlug || "");
        if (pending.length > 0)
            return pending;
        return String(Config.design.activeProfile || "");
    }

    function _seed() {
        if (String(Theme.pendingSlug || "").length > 0 && Theme.pendingSpec)
            return Theme._norm(Theme.pendingSpec);
        const slug = root._activeSlug();
        const list = Theme.profiles || [];
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].slug || "") === slug)
                return Theme._norm(list[i]);
        }
        return Theme._norm({ mode: "dark" });
    }

    function _bindPalettes(item) {
        if (!item)
            return;
        item.width = Qt.binding(() => palettesHost.width);
        item.variant = Qt.binding(() => String(root.seed.variant || "tonal-spot"));
        item.mode = Qt.binding(() => root.seed.mode === "light" ? "light" : "dark");
        item.contrast = Qt.binding(() => String(root.seed.contrast || "standard"));
    }

    MField {
        labelKey: "settings.fields.themeMode"
        MSegmented {
            value: root.seed.mode === "light" ? "light" : "dark"
            model: root.modeChoices
            enabled: !Theme.busy
            onSelected: (v) => {
                Theme.selectSpec(Object.assign({}, root.seed, { mode: v }));
            }
        }
    }

    MField {
        labelKey: "settings.fields.themeVariant"
        hintKey: "settings.hints.themeVariant"
        ColumnLayout {
            id: palettesHost
            spacing: Tokens.spacing.sm
            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: item ? item.implicitHeight : 0
                source: Qt.resolvedUrl("Palettes.qml")
                onLoaded: root._bindPalettes(item)
            }
            MSelect {
                visible: ThemePalettes.palettes.length === 0
                Layout.fillWidth: true
                model: root.variantChoices
                value: String(root.seed.variant || "tonal-spot")
                enabled: !Theme.busy
                onSelected: (v) => {
                    Theme.selectSpec(Object.assign({}, root.seed, { variant: v }));
                }
            }
        }
    }
}
