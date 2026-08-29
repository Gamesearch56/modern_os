import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md
    Model { id: sectionModel }

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.frecency"
        MSwitch {
            checked: sectionModel.frecencyEnabled
            onToggled: (v) => ConfigWrite.set("launcher.frecencyEnabled", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.showIcons"
        MSwitch {
            checked: Config.launcher.showIcons
            onToggled: (v) => ConfigWrite.set("launcher.showIcons", v)
        }
    }
    MField {
        labelKey: "settings.fields.launcherResults"
        MSlider {
            from: 4
            to: 20
            value: sectionModel.resultCount
            showValue: true
            onMoved: (v) => ConfigWrite.set("launcher.resultCount", Math.round(v))
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.showDescriptions"
        MSwitch {
            checked: !!(Config.launcher.showDescriptions)
            onToggled: (v) => ConfigWrite.set("launcher.showDescriptions", v)
        }
    }

    MSectionHeader { key: "settings.fields.providers" }
    Repeater {
        model: sectionModel.providerIds.length
        MListItem {
            required property int index
            readonly property string pid: String(sectionModel.providerIds[index] || "")
            Layout.fillWidth: true
            titleValue: pid
            MTextField {
                text: (Config.launcher.providers && Config.launcher.providers[pid])
                    ? (Config.launcher.providers[pid].prefix || "")
                    : ""
                placeholderKey: "settings.providerPrefixPlaceholder"
                onAccepted: {
                    const next = JSON.parse(JSON.stringify(Config.launcher.providers || {}));
                    if (!next[pid])
                        next[pid] = { enabled: true, prefix: "" };
                    next[pid].prefix = text;
                    ConfigWrite.set("launcher.providers", next);
                }
            }
        }
    }
}
