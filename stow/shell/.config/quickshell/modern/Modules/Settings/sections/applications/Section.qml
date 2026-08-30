import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    function _stem(id) {
        return String(id || "").replace(/\.desktop$/, "");
    }

    function setBackgroundApp(role, v) {
        const prev = String(Config.apps.defaults[role] || "");
        const id = String(v || "");
        ConfigWrite.set("apps.defaults." + role, id);
        const locked = {};
        const roles = ["calendar", "mail", "communication"];
        for (let r = 0; r < roles.length; r++) {
            const cur = roles[r] === role ? id : String(Config.apps.defaults[roles[r]] || "");
            if (cur.length > 0)
                locked[root._stem(cur)] = cur;
        }
        const next = [];
        const seen = {};
        const list = Config.general.autostart || [];
        for (let i = 0; i < list.length; i++) {
            const item = String(list[i] || "");
            const s = root._stem(item);
            if (s.length === 0 || seen[s])
                continue;
            if (s === root._stem(prev) && !locked[s])
                continue;
            seen[s] = true;
            next.push(item);
        }
        if (id.length > 0 && !seen[root._stem(id)])
            next.push(id);
        ConfigWrite.set("general.autostart", next);
        if (id.length > 0 && !Hypr.raiseDesktop(id))
            Apps.launchBackground(id);
    }

    MField {
        labelKey: "settings.fields.browser"
        MSelect {
            model: Apps.entriesFor("browser")
            value: Config.apps.defaults.browser
            onSelected: (v) => ConfigWrite.set("apps.defaults.browser", v)
        }
    }
    MField {
        labelKey: "settings.fields.calendar"
        MSelect {
            model: Apps.entriesFor("calendar")
            value: Config.apps.defaults.calendar
            allowEmpty: true
            onSelected: (v) => root.setBackgroundApp("calendar", v)
        }
    }
    MField {
        labelKey: "settings.fields.mail"
        MSelect {
            model: Apps.entriesFor("mail")
            value: Config.apps.defaults.mail
            allowEmpty: true
            onSelected: (v) => root.setBackgroundApp("mail", v)
        }
    }
    MField {
        labelKey: "settings.fields.communication"
        MSelect {
            model: Apps.entriesFor("communication")
            value: Config.apps.defaults.communication
            allowEmpty: true
            onSelected: (v) => root.setBackgroundApp("communication", v)
        }
    }
    MField {
        labelKey: "settings.fields.fileManager"
        MSelect {
            model: Apps.entriesFor("fileManager")
            value: Config.apps.defaults.fileManager
            onSelected: (v) => ConfigWrite.set("apps.defaults.fileManager", v)
        }
    }
    MField {
        labelKey: "settings.fields.terminal"
        MSelect {
            model: Apps.entriesFor("terminal")
            value: Config.apps.defaults.terminal
            onSelected: (v) => ConfigWrite.set("apps.defaults.terminal", v)
        }
    }

    Autostart {
        Layout.fillWidth: true
    }
}
