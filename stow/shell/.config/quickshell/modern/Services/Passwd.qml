// Local accounts for Settings → Users. getent is unprivileged; mutate
// is one pkexec of usersd.sh with JSON on stdin so passwords stay off argv.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property string loginName: Quickshell.env("USER") || ""
    property bool watching: false
    property bool running: false
    property string lastError: ""
    property var users: []
    property var others: []
    property var groups: []
    property var localGroups: []
    property var sessionUser: ({})
    readonly property bool canManage: rules.isAdmin(root.sessionUser) || rules.isAdmin({ groups: root.groups })
    readonly property bool canSetOwnGecos: own.canSetGecos
    property string _payload: ""

    PasswdParse { id: rules }
    PasswdSelf { id: own; host: root }

    function refresh() {
        if (!root.watching)
            return;
        snapProc.running = true;
        myGroupsProc.running = true;
    }

    function nameOk(s: var): bool { return rules.nameOk(s); }
    function gecosOk(s: var): bool { return rules.gecosOk(s); }
    function passwordOk(s: var): bool { return rules.passwordOk(s); }
    function isAdmin(person: var): bool { return rules.isAdmin(person); }
    function groupProtected(grp: var): bool { return rules.groupProtected(grp); }
    function canRenameGroup(grp: var): bool { return root.canManage && rules.canRenameGroup(grp, root.users); }
    function canDeleteGroup(grp: var): bool { return root.canManage && rules.canDeleteGroup(grp, root.users); }
    function userByLogin(login: string): var {
        return rules.findUser(root.users, login);
    }

    function canDemote(person: var): bool {
        return rules.canDemote(person, root.users, root.loginName);
    }
    function assignableGroups(login: string): var {
        return rules.assignableGroups(root.users, root.localGroups, login);
    }
    function canToggleMember(groupName: string, login: string): bool {
        return rules.canToggleMember(groupName, login, root.users, root.loginName);
    }

    function canDelete(login: string): bool {
        const u = String(login || "");
        if (!root.canManage || !u.length || u === root.loginName)
            return false;
        const person = rules.findUser(root.users, u);
        if (!person || person.uid === 0)
            return false;
        if (root.isAdmin(person) && rules.adminCount(root.users) < 2)
            return false;
        return true;
    }

    function canRename(login: string): bool {
        return String(login || "") !== root.loginName;
    }

    function setPassword() {
        Apps.runInTerminal(["passwd"]);
        Settings.close();
    }

    function setOwnGecos(name: string) { own.applyGecos(name); }

    function _requireManage(): bool {
        if (root.canManage)
            return true;
        root.lastError = I18n.t("settings.users.adminOnly");
        return false;
    }

    function createUser(fields) {
        if (!root._requireManage())
            return;
        const f = fields || ({});
        const u = String(f.login || "").trim();
        const gecos = String(f.gecos || "").trim();
        const password = String(f.password || "");
        const groups = f.groups || [];
        if (!rules.nameOk(u) || !rules.passwordOk(password)) {
            root.lastError = I18n.t("settings.users.invalid");
            return;
        }
        if (gecos.length && !rules.gecosOk(gecos)) {
            root.lastError = I18n.t("settings.users.invalid");
            return;
        }
        root._start({
            action: "create", username: u, gecos: gecos, password: password,
            groups: rules.sanitizeGroups(u, groups, root.isAdmin({ groups: groups }),
                root.users, root.localGroups, root.loginName)
        });
    }

    function updateUser(fields) {
        const f = fields || ({});
        const u = String(f.login || "").trim();
        if (!u.length) {
            root.lastError = I18n.t("settings.users.invalid");
            return;
        }
        if (u !== root.loginName && !root._requireManage())
            return;
        const body = { action: "update", username: u };
        const neu = String(f.newLogin || "").trim();
        if (neu.length && neu !== u) {
            if (!root.canRename(u) || !rules.nameOk(neu)) {
                root.lastError = I18n.t("settings.users.protected");
                return;
            }
            body.newUsername = neu;
        }
        const gecos = String(f.gecos || "").trim();
        if (gecos.length) {
            if (!rules.gecosOk(gecos)) {
                root.lastError = I18n.t("settings.users.invalid");
                return;
            }
            body.gecos = gecos;
        }
        const password = String(f.password || "");
        if (password.length) {
            if (u === root.loginName) {
                root.setPassword();
            } else if (!rules.passwordOk(password)) {
                root.lastError = I18n.t("settings.users.invalid");
                return;
            } else {
                body.password = password;
            }
        }
        if (Array.isArray(f.groups) && root.canManage) {
            const person = rules.findUser(root.users, u);
            body.groups = rules.sanitizeGroups(u, f.groups, root.isAdmin({
                groups: f.groups
            }) || (!root.canDemote(person) && root.isAdmin(person)),
                root.users, root.localGroups, root.loginName);
        }
        root._start(body);
    }

    function deleteUser(login: string, removeHome: bool) {
        if (!root._requireManage())
            return;
        const u = String(login || "");
        if (!root.canDelete(u)) {
            root.lastError = I18n.t("settings.users.protected");
            return;
        }
        root._start({ action: "delete", username: u, removeHome: !!removeHome });
    }

    function createGroup(name: string, members: var) {
        if (!root._requireManage())
            return;
        const g = String(name || "").trim();
        if (!rules.nameOk(g)) {
            root.lastError = I18n.t("settings.users.invalid");
            return;
        }
        const body = { action: "group-create", group: g };
        if (Array.isArray(members))
            body.members = rules.sanitizeMembers(g, members, root.users);
        root._start(body);
    }

    function updateGroup(fields) {
        if (!root._requireManage())
            return;
        const f = fields || ({});
        const g = String(f.name || "").trim();
        if (!g.length) {
            root.lastError = I18n.t("settings.users.invalid");
            return;
        }
        const body = { action: "group-update", group: g };
        const neu = String(f.newName || "").trim();
        if (neu.length && neu !== g) {
            const cur = rules.findGroup(root.localGroups, g);
            if (!root.canRenameGroup(cur || ({ name: g, gid: 0 })) || !rules.nameOk(neu)) {
                root.lastError = I18n.t("settings.users.protected");
                return;
            }
            body.newGroup = neu;
        }
        if (Array.isArray(f.members))
            body.members = rules.sanitizeMembers(g, f.members, root.users);
        root._start(body);
    }

    function deleteGroup(name: string): bool {
        if (!root._requireManage())
            return false;
        const g = String(name || "").trim();
        const grp = rules.findGroup(root.localGroups, g);
        if (!grp || !root.canDeleteGroup(grp)) {
            root.lastError = I18n.t("settings.users.protected");
            return false;
        }
        root._start({ action: "group-delete", group: g });
        return true;
    }

    function _start(body) {
        if (root.running)
            return;
        root.running = true;
        root.lastError = "";
        root._payload = JSON.stringify(body);
        mutateProc.running = false;
        mutateProc.stdinEnabled = true;
        mutateProc.command = ["pkexec", Paths.script("usersd.sh")];
        Qt.callLater(() => {
            if (root.running)
                mutateProc.running = true;
        });
    }

    function _applySnap(text: string) {
        const out = rules.parseSnap(text, root.loginName);
        root.users = out.users;
        root.others = out.users.filter(u => u.login !== root.loginName);
        root.localGroups = out.groups;
        const self = out.users.filter(u => u.login === root.loginName);
        root.sessionUser = self.length ? self[0] : ({ login: root.loginName, gecos: "", groups: [] });
    }

    Process {
        id: snapProc
        command: ["sh", "-c", "getent passwd | awk -F: 'BEGIN{OFS=\"\\t\"} $3>=1000 && $3<60000 {print $1,$3,$4,$5,$6,$7}'; echo ---; getent group | awk -F: 'BEGIN{OFS=\"\\t\"} {print $1,$3,$4}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._applySnap(this.text)
        }
    }

    Process {
        id: myGroupsProc
        command: ["id", "-nG"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.groups = this.text.trim().split(/\s+/).filter(s => s.length > 0)
        }
    }

    Process {
        id: mutateProc
        stdinEnabled: true
        running: false
        stderr: StdioCollector { id: errOut }
        onStarted: {
            mutateProc.write(root._payload);
            mutateProc.stdinEnabled = false;
            root._payload = "";
        }
        onExited: (code) => {
            mutateProc.stdinEnabled = true;
            mutateProc.running = false;
            root.lastError = code !== 0
                ? rules.mapError(String(errOut.text || "").trim()) : "";
            root.running = false;
            if (root.watching)
                root.refresh();
        }
    }

    function ensureGroups() {
        if (!myGroupsProc.running)
            myGroupsProc.running = true;
    }

    onWatchingChanged: { if (root.watching) root.refresh(); }
    Component.onCompleted: root.ensureGroups()
}
