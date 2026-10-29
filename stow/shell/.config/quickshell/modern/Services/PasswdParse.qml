// Unprivileged getent snapshot plus username / group grammar.
import QtQuick
import "../Commons"

QtObject {
    id: root

    readonly property var reserved: ["root", "nobody", "greeter", "daemon", "bin", "sys", "sync", "shutdown", "halt", "mail", "ftp"]

    function nameOk(s): bool {
        const t = String(s || "");
        if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(t))
            return false;
        return root.reserved.indexOf(t) === -1;
    }

    function gecosOk(s): bool {
        const t = String(s || "");
        return t.length > 0 && t.length <= 64 && t.indexOf(":") === -1 && t.indexOf("\n") === -1;
    }

    function passwordOk(s): bool {
        const t = String(s || "");
        return t.length > 0 && t.length <= 256 && t.indexOf("\n") === -1;
    }

    function isAdmin(person): bool {
        const g = (person && person.groups) ? person.groups : [];
        return g.indexOf("wheel") !== -1 || g.indexOf("sudo") !== -1;
    }

    function groupProtected(grp): bool {
        const gid = Number(grp && grp.gid);
        return !(gid >= 1000);
    }

    function canRenameGroup(grp, people): bool {
        if (root.groupProtected(grp))
            return false;
        const n = grp && grp.name ? String(grp.name) : "";
        return !!n && !root.isUserPrivateGroup(n, people);
    }

    function canDeleteGroup(grp, people): bool {
        return root.canRenameGroup(grp, people);
    }

    function mapError(text: string): string {
        const t = String(text || "").toLowerCase();
        if (t.indexOf("invoking") !== -1 || t.indexOf("uid 0") !== -1 || t.indexOf("protected") !== -1)
            return I18n.t("settings.users.protected");
        if (t.indexOf("last administrator") !== -1)
            return I18n.t("settings.users.lastAdmin");
        if (t.indexOf("invalid") !== -1)
            return I18n.t("settings.users.invalid");
        if (t.indexOf("currently used") !== -1 || t.indexOf("signed in") !== -1)
            return I18n.t("settings.users.busy");
        return I18n.t("settings.users.failed");
    }

    function findUser(people, login: string) {
        const rows = people || [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].login === login)
                return rows[i];
        }
        return null;
    }

    function findGroup(rows, name: string) {
        const list = rows || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === name)
                return list[i];
        }
        return null;
    }

    function isAdminGroup(name: string): bool {
        return name === "wheel" || name === "sudo";
    }

    function primaryName(person): string {
        if (!person)
            return "";
        const g = person.groups || [];
        if (g.length)
            return g[0];
        return person.login || "";
    }

    function isUserPrivateGroup(name: string, people): bool {
        return !!root.findUser(people, name);
    }

    function adminGroupName(groups): string {
        const rows = groups || [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].name === "wheel")
                return "wheel";
            if (rows[i].name === "sudo")
                return "sudo";
        }
        return "wheel";
    }

    function canDemote(person, people, sessionLogin: string): bool {
        if (!person || person.login === sessionLogin)
            return false;
        if (!root.isAdmin(person))
            return true;
        return root.adminCount(people) > 1;
    }

    function assignableGroups(people, groups, login: string) {
        const person = root.findUser(people, login);
        const prim = root.primaryName(person) || login;
        const out = [];
        const rows = groups || [];
        for (let i = 0; i < rows.length; i++) {
            const n = rows[i].name || "";
            if (!n || n === prim || root.isAdminGroup(n) || root.isUserPrivateGroup(n, people))
                continue;
            out.push(n);
        }
        return out;
    }

    function canToggleMember(groupName: string, login: string, people, sessionLogin: string): bool {
        const g = String(groupName || "");
        const u = String(login || "");
        if (!g || !u)
            return false;
        if (root.isUserPrivateGroup(g, people))
            return false;
        if (root.isAdminGroup(g)) {
            const p = root.findUser(people, u);
            if (p && root.isAdmin(p))
                return false;
        }
        return true;
    }

    function sanitizeGroups(login: string, selected, admin: bool, people, groups, sessionLogin: string) {
        const person = root.findUser(people, login);
        const allow = root.assignableGroups(people, groups, login);
        const want = selected || [];
        const out = [];
        for (let i = 0; i < want.length; i++) {
            if (allow.indexOf(want[i]) !== -1 && out.indexOf(want[i]) === -1)
                out.push(want[i]);
        }
        const prim = root.primaryName(person);
        if (prim && out.indexOf(prim) === -1)
            out.push(prim);
        const keepAdmin = !!admin || (!!person && root.isAdmin(person)
            && !root.canDemote(person, people, sessionLogin));
        if (keepAdmin) {
            const ag = root.adminGroupName(groups);
            if (ag && out.indexOf(ag) === -1)
                out.push(ag);
        }
        return out;
    }

    function sanitizeMembers(groupName: string, members, people) {
        const g = String(groupName || "");
        if (root.isUserPrivateGroup(g, people))
            return [g];
        let out = [];
        const want = members || [];
        for (let i = 0; i < want.length; i++) {
            if (out.indexOf(want[i]) === -1)
                out.push(want[i]);
        }
        if (root.isAdminGroup(g)) {
            const rows = people || [];
            for (let i = 0; i < rows.length; i++) {
                if (!root.isAdmin(rows[i]))
                    continue;
                const login = rows[i].login || "";
                if (login && out.indexOf(login) === -1)
                    out.push(login);
            }
        }
        return out;
    }

    function adminCount(people): int {
        const rows = people || [];
        let n = 0;
        for (let i = 0; i < rows.length; i++) {
            if (root.isAdmin(rows[i]))
                n++;
        }
        return n;
    }

    function parseSnap(text, loginName) {
        const parts = (text || "").split("\n---\n");
        const people = [];
        const passLines = (parts[0] || "").trim().split("\n");
        for (let i = 0; i < passLines.length; i++) {
            const p = passLines[i].split("\t");
            if (p.length < 6)
                continue;
            const uid = Number(p[1]);
            const gecos = (p[3] || "").split(",")[0];
            const shell = p[5] || "";
            const home = p[4] || "";
            if (uid < 1000 || uid >= 60000)
                continue;
            if (shell.indexOf("nologin") !== -1 || shell.indexOf("false") !== -1)
                continue;
            if (home.indexOf("/run/") === 0 || gecos === "Dynamic User")
                continue;
            people.push({
                login: p[0], uid: uid, gid: Number(p[2]), gecos: gecos,
                home: home, shell: shell, groups: [], session: p[0] === loginName
            });
        }
        const table = [];
        const gLines = (parts[1] || "").trim().split("\n");
        for (let i = 0; i < gLines.length; i++) {
            const p = gLines[i].split("\t");
            if (!p[0])
                continue;
            table.push({
                name: p[0],
                gid: Number(p[1] || 0),
                members: (p[2] || "").split(",").map(s => s.trim()).filter(s => s.length > 0)
            });
        }
        const byGid = ({});
        for (let i = 0; i < table.length; i++)
            byGid[table[i].gid] = table[i];
        for (let i = 0; i < people.length; i++) {
            const names = [];
            const primary = byGid[people[i].gid];
            if (primary)
                names.push(primary.name);
            for (let j = 0; j < table.length; j++) {
                if ((table[j].members || []).indexOf(people[i].login) !== -1 && names.indexOf(table[j].name) === -1)
                    names.push(table[j].name);
            }
            people[i].groups = names;
        }
        const logins = people.map(u => u.login);
        const shown = [];
        for (let i = 0; i < table.length; i++) {
            const g = table[i];
            const mem = (g.members || []).slice();
            for (let j = 0; j < people.length; j++) {
                if (people[j].gid === g.gid && mem.indexOf(people[j].login) === -1)
                    mem.push(people[j].login);
            }
            const humans = mem.filter(n => logins.indexOf(n) !== -1);
            if (g.gid >= 1000 || humans.length > 0)
                shown.push({ name: g.name, gid: g.gid, members: humans, protected: g.gid < 1000 });
        }
        return { users: people, groups: shown };
    }
}