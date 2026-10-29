import QtQuick
import QtQuick.Layouts
import QtQuick.Window
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

    function closeOverlays() {
        if (picker.open) {
            picker.open = false;
            return true;
        }
        return false;
    }

    function applyRole(role, v) {
        if (role === "calendar" || role === "mail" || role === "communication") {
            root.setBackgroundApp(role, v);
            return;
        }
        ConfigWrite.set("apps.defaults." + role, String(v || ""));
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

    MSectionHeader {
        key: "settings.applications.web"
        hintKey: "settings.applications.hint"
        topMargin: 0
    }
    RoleRow { role: "browser"; onPick: picker.openRole(role, false) }
    RoleRow {
        id: calendarRow
        role: "calendar"
        allowEmpty: true
        onPick: picker.openRole(role, true)
    }
    RoleRow { role: "mail"; allowEmpty: true; onPick: picker.openRole(role, true) }
    RoleRow { role: "communication"; allowEmpty: true; onPick: picker.openRole(role, true) }

    MSectionHeader {
        key: "settings.applications.files"
        topMargin: Tokens.spacing.xxl
    }
    RoleRow { role: "fileManager"; onPick: picker.openRole(role, false) }
    RoleRow { role: "videoPlayer"; onPick: picker.openRole(role, false) }
    RoleRow { role: "imageViewer"; onPick: picker.openRole(role, false) }
    RoleRow { role: "textEditor"; onPick: picker.openRole(role, false) }
    RoleRow { role: "terminal"; onPick: picker.openRole(role, false) }

    Autostart {
        Layout.fillWidth: true
    }

    RolePicker {
        id: picker
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        enabled: picker.open
        onPicked: (role, id) => root.applyRole(role, id)
    }

    function _flickable() {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    function _scrollToCalendar() {
        if (Settings.subsectionId !== "calendar")
            return;
        if (calendarRow.height <= 0)
            return;
        const flick = root._flickable();
        if (!flick)
            return;
        const pos = calendarRow.mapToItem(flick.contentItem, 0, 0);
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.min(maxY, Math.max(0, pos.y - Tokens.spacing.md));
        Settings.subsectionId = "";
    }

    Connections {
        target: Settings
        function onSubsectionIdChanged() { Qt.callLater(root._scrollToCalendar); }
    }

    Component.onCompleted: Qt.callLater(root._scrollToCalendar)
    onImplicitHeightChanged: Qt.callLater(root._scrollToCalendar)
}
