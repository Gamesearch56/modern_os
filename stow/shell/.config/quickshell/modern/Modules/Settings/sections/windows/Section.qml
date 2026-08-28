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

    MSectionHeader { key: "settings.fields.titlebar" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.titlebar"
        MSwitch {
            checked: Config.windows?.titlebar ?? true
            onToggled: (v) => ConfigWrite.set("windows.titlebar", v)
        }
    }
    MHint {
        key: Hypr.hyprbarsLoaded ? "settings.hints.hyprbarsOn" : "settings.hints.hyprbarsOff"
        Layout.fillWidth: true
    }

    MSectionHeader { key: "settings.fields.gaps" }
    MField {
        labelKey: "settings.fields.gapsIn"
        MSlider {
            from: 0
            to: 24
            value: Config.windows?.gapsIn ?? 5
            showValue: true
            onMoved: (v) => ConfigWrite.set("windows.gapsIn", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.gapsOut"
        MSlider {
            from: 0
            to: 40
            value: Config.windows?.gapsOut ?? 10
            showValue: true
            onMoved: (v) => ConfigWrite.set("windows.gapsOut", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.windowOpacity"
        MSlider {
            from: 0.5
            to: 1
            value: Config.windows?.opacity ?? 1
            onMoved: (v) => ConfigWrite.set("windows.opacity", Math.round(v * 100) / 100)
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
                    if (!Array.isArray(parsed))
                        throw "not an array";
                    ConfigWrite.set("windowRules", parsed);
                    root.rulesError = "";
                } catch (e) {
                    root.rulesError = String(e);
                    Logger.error("Windows", String(e));
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
