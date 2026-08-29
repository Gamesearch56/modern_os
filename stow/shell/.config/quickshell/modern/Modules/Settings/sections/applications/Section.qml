import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    Model { id: model }

    function setBackgroundApp(role, v) {
        const id = String(v || "");
        ConfigWrite.set("apps.defaults." + role, id);
        const cur = Config.general.autostart || [];
        let found = false;
        for (let i = 0; i < cur.length; i++) {
            if (String(cur[i]) === id) {
                found = true;
                break;
            }
        }
        if (!found && id.length > 0) {
            const next = cur.slice();
            next.push(id);
            ConfigWrite.set("general.autostart", next);
        }
        if (!Hypr.raiseDesktop(id))
            Apps.launchBackground(id);
    }

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
            onSelected: (v) => root.setBackgroundApp("calendar", v)
        }
    }
    MField {
        labelKey: "settings.fields.mail"
        MSelect {
            model: Apps.allEntries()
            value: Config.apps.defaults.mail
            onSelected: (v) => root.setBackgroundApp("mail", v)
        }
    }
    MField {
        labelKey: "settings.fields.communication"
        MSelect {
            model: Apps.allEntries()
            value: Config.apps.defaults.communication
            onSelected: (v) => root.setBackgroundApp("communication", v)
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
