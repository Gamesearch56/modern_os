import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property string draftRules: JSON.stringify(Config.windowRules || [], null, 2)
    property string rulesError: ""

    MField {
        labelKey: "settings.fields.transparency"
        MSlider {
            from: 0.4
            to: 1
            value: Config.design.transparency
            onCommitted: (v) => ConfigWrite.set("design.transparency", Math.round(v * 100) / 100)
        }
    }
    MField {
        labelKey: "settings.fields.cornerRounding"
        MSlider {
            from: 0.5
            to: 1.5
            value: Config.design.cornerRounding
            onMoved: (v) => {
                const n = Math.round(v * 100) / 100;
                Hypr.keyword("decoration:rounding", String(Math.floor(16 * n)));
            }
            onCommitted: (v) => ConfigWrite.set("design.cornerRounding", Math.round(v * 100) / 100)
        }
    }

    MSectionHeader { key: "settings.fields.gaps" }
    MField {
        labelKey: "settings.fields.gapsIn"
        MSlider {
            from: 0
            to: 24
            value: Config.windows?.gapsIn ?? 5
            showValue: true
            onMoved: (v) => Hypr.keyword("general:gaps_in", String(Math.round(v)))
            onCommitted: (v) => ConfigWrite.set("windows.gapsIn", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.gapsOut"
        MSlider {
            from: 0
            to: 40
            value: Config.windows?.gapsOut ?? 10
            showValue: true
            onMoved: (v) => Hypr.keyword("general:gaps_out", String(Math.round(v)))
            onCommitted: (v) => ConfigWrite.set("windows.gapsOut", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.windowOpacity"
        MSlider {
            from: 0.5
            to: 1
            value: Config.windows?.opacity ?? 1
            onMoved: (v) => {
                const n = Math.round(v * 100) / 100;
                Hypr.keyword("decoration:active_opacity", String(n));
                Hypr.keyword("decoration:inactive_opacity", String(Math.min(1, n * 0.98)));
            }
            onCommitted: (v) => ConfigWrite.set("windows.opacity", Math.round(v * 100) / 100)
        }
    }

    MSectionHeader { key: "settings.fields.windowRules" }
    MTextArea {
        Layout.fillWidth: true
        expanded: true
        text: root.draftRules
        placeholderKey: "settings.hints.windowRulesJson"
        onTextEdited: root.draftRules = text
    }
    MText {
        visible: root.rulesError.length > 0
        value: root.rulesError
        styleName: "bodySmall"
        color: Colors.color.error
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
    RowLayout {
        MButton {
            kind: "filled"
            key: "settings.save"
            onClicked: {
                try {
                    const parsed = JSON.parse(root.draftRules);
                    if (!Array.isArray(parsed)) {
                        root.rulesError = I18n.t("settings.windows.rulesNotArray");
                        return;
                    }
                    ConfigWrite.set("windowRules", parsed);
                    root.rulesError = "";
                } catch (e) {
                    root.rulesError = I18n.t("settings.windows.rulesInvalid");
                    Logger.error("Windows", I18n.t("settings.windows.rulesInvalid"));
                }
            }
        }
        MButton {
            kind: "tonal"
            key: "settings.cancel"
            onClicked: {
                root.draftRules = JSON.stringify(Config.windowRules || [], null, 2);
                root.rulesError = "";
            }
        }
    }
}
