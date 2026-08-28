import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    Model { id: model }

    MSectionHeader {
        key: "settings.fields.defaultApps"
        hintKey: "settings.hints.defaultApps"
    }

    MField {
        labelKey: "settings.fields.browser"
        MSelect {
            model: Apps.allEntries()
            value: Config.apps.defaults.browser
            onSelected: (v) => ConfigWrite.set("apps.defaults.browser", v)
        }
    }
    MField {
        labelKey: "settings.fields.calendar"
        MSelect {
            model: Apps.allEntries()
            value: Config.apps.defaults.calendar
            onSelected: (v) => ConfigWrite.set("apps.defaults.calendar", v)
        }
    }
    MField {
        labelKey: "settings.fields.fileManager"
        MSelect {
            model: Apps.allEntries()
            value: Config.apps.defaults.fileManager
            onSelected: (v) => ConfigWrite.set("apps.defaults.fileManager", v)
        }
    }
    MField {
        labelKey: "settings.fields.terminal"
        MSelect {
            model: Apps.allEntries()
            value: Config.apps.defaults.terminal
            onSelected: (v) => ConfigWrite.set("apps.defaults.terminal", v)
        }
    }

    MSectionHeader {
        key: "settings.fields.autostart"
    }

    Repeater {
        model: Config.general.autostart
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: String(modelData)
            MIconButton {
                iconName: "list-remove"
                onClicked: {
                    const next = [];
                    const cur = Config.general.autostart || [];
                    for (let i = 0; i < cur.length; i++) {
                        if (cur[i] !== modelData)
                            next.push(cur[i]);
                    }
                    ConfigWrite.set("general.autostart", next);
                }
            }
        }
    }

    MEmptyState {
        visible: (Config.general.autostart || []).length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "application-x-executable"
        titleKey: "settings.empty.autostart"
    }

    MSelect {
        Layout.fillWidth: true
        placeholderKey: "settings.addAutostart"
        model: Apps.allEntries()
        onSelected: (v) => {
            const cur = Config.general.autostart || [];
            const next = cur.slice();
            next.push(v);
            ConfigWrite.set("general.autostart", next);
        }
    }
}
