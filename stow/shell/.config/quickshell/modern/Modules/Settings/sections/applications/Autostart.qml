import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    readonly property var entries: Config.general.autostart || []

    function _stem(id) {
        return String(id || "").replace(/\.desktop$/, "");
    }

    function _locked() {
        const out = {};
        const roles = ["calendar", "mail", "communication"];
        for (let i = 0; i < roles.length; i++) {
            const id = String(Config.apps.defaults[roles[i]] || "");
            if (id.length > 0)
                out[root._stem(id)] = true;
        }
        return out;
    }

    function _addChoices() {
        const all = Apps.allEntries() || [];
        const have = {};
        const list = root.entries;
        for (let i = 0; i < list.length; i++)
            have[root._stem(list[i])] = true;
        const out = [];
        for (let j = 0; j < all.length; j++) {
            const row = all[j];
            if (!have[root._stem(row.value)])
                out.push(row);
        }
        return out;
    }

    function removeId(id) {
        const next = [];
        const list = root.entries;
        const skip = root._stem(id);
        for (let i = 0; i < list.length; i++) {
            if (root._stem(list[i]) !== skip)
                next.push(list[i]);
        }
        ConfigWrite.set("general.autostart", next);
    }

    MSectionHeader {
        key: "settings.fields.autostart"
        topMargin: Tokens.spacing.xxl
    }

    Repeater {
        model: root.entries
        MListItem {
            required property var modelData
            readonly property string appId: String(modelData || "")
            readonly property bool locked: {
                void Config.apps.defaults.calendar;
                void Config.apps.defaults.mail;
                void Config.apps.defaults.communication;
                return !!(root._locked()[root._stem(appId)]);
            }
            Layout.fillWidth: true
            hoverHighlight: false
            tintIcon: false
            iconName: Apps.iconForId(appId)
            titleValue: Apps.labelForId(appId)
            MIconButton {
                visible: !locked
                iconName: "list-remove"
                onClicked: root.removeId(appId)
            }
        }
    }

    MEmptyState {
        visible: root.entries.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "application-x-executable"
        titleKey: "settings.empty.autostart"
    }

    MSelect {
        id: addPick
        Layout.fillWidth: true
        placeholderKey: "settings.addAutostart"
        value: ""
        model: root._addChoices()
        onSelected: (v) => {
            const id = String(v || "");
            if (id.length === 0)
                return;
            const next = root.entries.slice();
            next.push(id);
            ConfigWrite.set("general.autostart", next);
            addPick.value = "";
        }
    }
}
