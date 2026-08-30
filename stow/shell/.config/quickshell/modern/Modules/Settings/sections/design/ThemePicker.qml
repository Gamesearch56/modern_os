import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

GridLayout {
    id: root
    Layout.fillWidth: true
    columns: 4
    columnSpacing: Tokens.spacing.md
    rowSpacing: Tokens.spacing.md

    readonly property var cards: {
        void Theme.profiles;
        void Theme.pendingSlug;
        void Config.design.activeProfile;
        return root._cards();
    }

    function _activeSlug() {
        const pending = String(Theme.pendingSlug || "");
        if (pending.length > 0)
            return pending;
        return String(Config.design.activeProfile || "");
    }

    function _cards() {
        const slug = root._activeSlug();
        const list = Theme.profiles || [];
        let seed = Theme._norm({});
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].slug || "") === slug)
                seed = Theme._norm(list[i]);
        }
        const out = [];
        const modes = ["dark", "light"];
        const contrasts = ["standard", "high"];
        for (let m = 0; m < modes.length; m++) {
            for (let c = 0; c < contrasts.length; c++) {
                const spec = Object.assign({}, seed, { mode: modes[m], contrast: contrasts[c] });
                const cardSlug = Theme.findSlug(spec) || Theme.slugFor(spec);
                out.push({
                    slug: cardSlug,
                    spec: spec,
                    active: cardSlug === slug
                });
            }
        }
        return out;
    }

    function _modeKey(mode) {
        if (mode === "light")
            return "settings.themeModeLight";
        if (mode === "auto")
            return "settings.themeModeAuto";
        return "settings.themeModeDark";
    }

    function _contrastKey(contrast) {
        if (contrast === "high")
            return "settings.themeContrastHigh";
        if (contrast === "medium")
            return "settings.themeContrastMedium";
        return "settings.themeContrastStandard";
    }

    function _swatches(spec, active) {
        void Colors.color;
        const c = Colors.color;
        if (active)
            return [c.primary, c.secondary, c.tertiary];
        if (spec.mode === "light" && spec.contrast === "high")
            return [c.inversePrimary, c.onSurface, c.tertiary];
        if (spec.mode === "light")
            return [c.inversePrimary, c.primaryContainer, c.tertiaryContainer];
        if (spec.contrast === "high")
            return [c.onSurface, c.primary, c.secondary];
        return [c.secondary, c.tertiary, c.primary];
    }

    Repeater {
        model: root.cards
        MCard {
            required property var modelData
            readonly property var card: modelData || ({})
            readonly property var spec: card.spec || ({})
            readonly property bool active: card.active === true
            readonly property var swatches: root._swatches(spec, active)
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: Tokens.spacing.xxl * 4
            level: active ? 3 : 1
            highlighted: active

            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.xs
                MText {
                    value: String(card.slug || "")
                    styleName: "labelLarge"
                    Layout.fillWidth: true
                }
                MText {
                    key: "settings.themeProfileHint"
                    params: ({
                        mode: I18n.t(root._modeKey(spec.mode)),
                        contrast: I18n.t(root._contrastKey(spec.contrast))
                    })
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                Item { Layout.fillHeight: true }
                Row {
                    id: dots
                    readonly property var palette: swatches
                    spacing: Tokens.spacing.xs
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: Tokens.spacing.md
                            height: Tokens.spacing.md
                            radius: Tokens.radius.full
                            color: dots.palette[index]
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Theme.selectSpec(spec)
            }
        }
    }
}
