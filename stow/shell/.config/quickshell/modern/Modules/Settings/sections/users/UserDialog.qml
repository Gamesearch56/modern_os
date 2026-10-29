import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MDialog {
    id: root

    property bool creating: true
    property string originLogin: ""
    property string login: ""
    property string gecos: ""
    property var selected: []
    property string password: ""
    property string confirm: ""
    property bool admin: false

    readonly property bool session: !root.creating && root.login === Passwd.loginName
    readonly property string adminGroup: {
        const rows = Passwd.localGroups || [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].name === "wheel")
                return "wheel";
            if (rows[i].name === "sudo")
                return "sudo";
        }
        return "wheel";
    }
    readonly property var catalog: Passwd.assignableGroups(root.originLogin || root.login)
    readonly property var person: Passwd.userByLogin(root.originLogin)
    readonly property bool canDemote: Passwd.canDemote(root.person)
    readonly property bool _passOk: {
        if (root.session)
            return true;
        if (root.creating)
            return Passwd.passwordOk(root.password) && root.password === root.confirm;
        if (!root.password.length)
            return true;
        return Passwd.passwordOk(root.password) && root.password === root.confirm;
    }
    readonly property bool _valid: {
        if (!Passwd.nameOk(root.login) || !root._passOk)
            return false;
        if (root.gecos.length && !Passwd.gecosOk(root.gecos))
            return false;
        return true;
    }

    wide: true
    titleKey: root.creating ? "settings.users.addUser" : "settings.users.editTitle"
    confirmKey: root.creating ? "settings.users.addUser" : "settings.save"
    cancelKey: "settings.cancel"
    confirmEnabled: root._valid && !Passwd.running
    onCancelled: root.open = false
    onConfirmed: root._save()

    function load(person) {
        const p = person || ({});
        root.creating = false;
        root.originLogin = p.login || "";
        root.login = p.login || "";
        root.gecos = p.gecos || "";
        root.selected = (p.groups || []).slice();
        root.admin = Passwd.isAdmin(p);
        root.password = "";
        root.confirm = "";
        if (loginField)
            loginField.text = root.login;
        if (gecosField)
            gecosField.text = root.gecos;
        if (passField)
            passField.text = "";
        if (confirmField)
            confirmField.text = "";
    }

    function reset() {
        root.creating = true;
        root.originLogin = "";
        root.login = "";
        root.gecos = "";
        root.selected = [];
        root.admin = false;
        root.password = "";
        root.confirm = "";
        if (loginField)
            loginField.text = "";
        if (gecosField)
            gecosField.text = "";
        if (passField)
            passField.text = "";
        if (confirmField)
            confirmField.text = "";
    }

    function _toggle(name: string) {
        if (Passwd.groupProtected({ name: name, gid: 0 }) && name === root.adminGroup)
            return;
        const cur = (root.selected || []).slice();
        const i = cur.indexOf(name);
        if (i === -1)
            cur.push(name);
        else
            cur.splice(i, 1);
        root.selected = cur;
    }

    function _save() {
        if (!root._valid)
            return;
        let groups = (root.selected || []).slice();
        const g = root.adminGroup;
        const has = groups.indexOf(g) !== -1;
        if (root.admin && !has)
            groups.push(g);
        if (!root.admin && has)
            groups = groups.filter(n => n !== g);
        if (root.creating) {
            if (!Passwd.canManage)
                return;
            Passwd.createUser({
                login: root.login, gecos: root.gecos,
                password: root.password, groups: groups
            });
        } else if (root.session) {
            Passwd.updateUser(Passwd.canManage
                ? { login: root.originLogin, gecos: root.gecos, groups: groups }
                : { login: root.originLogin, gecos: root.gecos });
        } else {
            if (!Passwd.canManage)
                return;
            Passwd.updateUser({
                login: root.originLogin, newLogin: root.login,
                gecos: root.gecos, password: root.password, groups: groups
            });
        }
        root.open = false;
    }

    MField {
        labelKey: "settings.users.username"
        MTextField {
            id: loginField
            enabled: root.creating || !root.session
            onTextEdited: root.login = loginField.text.trim()
        }
    }
    MField {
        labelKey: "settings.users.displayName"
        hintKey: "settings.users.displayNameHint"
        MTextField {
            id: gecosField
            onTextEdited: root.gecos = gecosField.text
        }
    }
    MField {
        visible: !root.session
        labelKey: "settings.users.password"
        hintKey: root.creating ? "" : "settings.users.passwordKeep"
        MTextField {
            id: passField
            echoMode: TextInput.Password
            onTextEdited: root.password = passField.text
        }
    }
    MField {
        visible: !root.session
        labelKey: "settings.users.passwordConfirm"
        MTextField {
            id: confirmField
            echoMode: TextInput.Password
            onTextEdited: root.confirm = confirmField.text
        }
    }
    MButton {
        visible: root.session
        kind: "text"
        key: "settings.users.changePassword"
        onClicked: Passwd.setPassword()
    }
    RowLayout {
        visible: Passwd.canManage
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.users.colAdmin"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: root.admin
            enabled: Passwd.canManage && (!root.admin || root.canDemote || root.creating)
            onToggled: (v) => {
                if (!v && !root.creating && !root.canDemote) {
                    root.admin = true;
                    return;
                }
                root.admin = v;
                const cur = (root.selected || []).slice();
                const g = root.adminGroup;
                const i = cur.indexOf(g);
                if (v && i === -1)
                    cur.push(g);
                if (!v && i !== -1)
                    cur.splice(i, 1);
                root.selected = cur;
            }
        }
    }
    MField {
        visible: Passwd.canManage
        labelKey: "settings.users.groups"
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            Repeater {
                model: root.catalog
                MChip {
                    required property var modelData
                    value: modelData
                    checked: (root.selected || []).indexOf(modelData) !== -1
                    onClicked: root._toggle(modelData)
                }
            }
        }
    }
}