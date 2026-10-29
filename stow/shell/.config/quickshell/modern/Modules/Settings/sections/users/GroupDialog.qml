import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MDialog {
    id: root

    property bool creating: true
    property string originName: ""
    property string name: ""
    property var selected: []
    property bool locked: false

    readonly property var people: Passwd.users || []
    readonly property bool _valid: Passwd.nameOk(root.name)

    wide: true
    titleKey: root.creating ? "settings.users.addGroup" : "settings.users.editGroup"
    confirmKey: root.creating ? "settings.users.addGroup" : "settings.save"
    cancelKey: "settings.cancel"
    confirmEnabled: root._valid && !Passwd.running
    onCancelled: root.open = false
    onConfirmed: root._save()

    function load(grp) {
        const g = grp || ({});
        root.creating = false;
        root.originName = g.name || "";
        root.name = g.name || "";
        root.selected = (g.members || []).slice();
        root.locked = !Passwd.canRenameGroup(g);
        if (nameField)
            nameField.text = root.name;
    }

    function reset() {
        root.creating = true;
        root.originName = "";
        root.name = "";
        root.selected = [];
        root.locked = false;
        if (nameField)
            nameField.text = "";
    }

    function _canToggle(login: string): bool {
        const g = root.originName || root.name;
        if (root.creating && !g.length)
            return true;
        return Passwd.canToggleMember(g, login);
    }

    function _toggle(login: string) {
        if (!root._canToggle(login))
            return;
        const cur = (root.selected || []).slice();
        const i = cur.indexOf(login);
        if (i === -1)
            cur.push(login);
        else
            cur.splice(i, 1);
        root.selected = cur;
    }

    function _save() {
        if (!root._valid || !Passwd.canManage)
            return;
        if (root.creating) {
            Passwd.createGroup(root.name, root.selected);
        } else {
            Passwd.updateGroup({
                name: root.originName || root.name,
                newName: root.name, members: root.selected
            });
        }
        root.open = false;
    }

    MField {
        labelKey: "settings.users.groupName"
        MTextField {
            id: nameField
            enabled: root.creating || !root.locked
            onTextEdited: root.name = nameField.text.trim()
        }
    }
    MField {
        labelKey: "settings.users.members"
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            Repeater {
                model: root.people.length
                MChip {
                    required property int index
                    readonly property var person: root.people[index] || ({})
                    value: person.login || ""
                    checked: (root.selected || []).indexOf(person.login || "") !== -1
                    enabled: root._canToggle(person.login || "")
                    onClicked: root._toggle(person.login || "")
                }
            }
        }
    }
}