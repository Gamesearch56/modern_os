import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property string editorId: ""
    readonly property bool editorOpen: root.editorId.length > 0

    readonly property var catalog: [
        "launcher", "ai", "workspaces", "media", "tray", "taskbar",
        "clock", "weather", "calendar", "mail", "connectivity", "network",
        "bluetooth", "audio", "microphone", "battery", "performance",
        "vpn", "kdeconnect", "notifications", "settings", "power"
    ]

    function widgetKey(id) {
        if (id === "calendar")
            return "calendar.title";
        if (id === "ai")
            return "ai.title";
        return "bar." + id;
    }

    function _in(arr, id) {
        const list = arr || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] === id)
                return true;
        }
        return false;
    }

    function _toggle(id, on) {
        if (on) {
            if (root._in(Config.bar.left, id) || root._in(Config.bar.center, id) || root._in(Config.bar.right, id))
                return;
            const next = (Config.bar.right || []).slice();
            next.push(id);
            ConfigWrite.set("bar.right", next);
            return;
        }
        const slots = ["left", "center", "right"];
        for (let s = 0; s < slots.length; s++) {
            const slot = slots[s];
            const cur = (Config.bar[slot] || []).slice();
            const next = [];
            for (let i = 0; i < cur.length; i++) {
                if (cur[i] !== id)
                    next.push(cur[i]);
            }
            if (next.length !== cur.length)
                ConfigWrite.set("bar." + slot, next);
        }
    }

    function _enabled(id) {
        return root._in(Config.bar.left, id) || root._in(Config.bar.center, id) || root._in(Config.bar.right, id);
    }

    MSectionHeader { key: "settings.fields.barPosition" }
    MSegmented {
        Layout.fillWidth: true
        value: Config.bar.position
        model: [
            { value: "top", titleKey: "settings.barTop" },
            { value: "bottom", titleKey: "settings.barBottom" },
            { value: "left", titleKey: "settings.barLeft" },
            { value: "right", titleKey: "settings.barRight" }
        ]
        onSelected: (v) => ConfigWrite.set("bar.position", v)
    }

    MSectionHeader { key: "settings.fields.barStyle" }
    MSegmented {
        Layout.fillWidth: true
        value: Config.bar.style
        model: [
            { value: "floating", titleKey: "settings.barFloating" },
            { value: "attached", titleKey: "settings.barAttached" }
        ]
        onSelected: (v) => ConfigWrite.set("bar.style", v)
    }

    MField {
        labelKey: "settings.fields.barHeight"
        MSlider {
            from: 28
            to: 56
            value: Config.bar.height
            showValue: true
            onMoved: (v) => ConfigWrite.set("bar.height", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.edgeGap"
        MSlider {
            from: 0
            to: 24
            value: Config.bar.edgeGap ?? 8
            showValue: true
            onMoved: (v) => ConfigWrite.set("bar.edgeGap", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.endGap"
        MSlider {
            from: 0
            to: 24
            value: Config.bar.endGap ?? 8
            showValue: true
            onMoved: (v) => ConfigWrite.set("bar.endGap", Math.round(v))
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.autoHide"
        MSwitch {
            checked: !!(Config.bar.autoHide)
            onToggled: (v) => ConfigWrite.set("bar.autoHide", v)
        }
    }

    MSectionHeader { key: "settings.fields.barLeft" }
    MReorderList {
        Layout.fillWidth: true
        items: Config.bar.left || []
        labelKey: root.widgetKey
        onReordered: (next) => ConfigWrite.set("bar.left", next)
        onItemClicked: (id) => root.editorId = id
    }
    MSectionHeader { key: "settings.fields.barCenter" }
    MReorderList {
        Layout.fillWidth: true
        items: Config.bar.center || []
        labelKey: root.widgetKey
        onReordered: (next) => ConfigWrite.set("bar.center", next)
        onItemClicked: (id) => root.editorId = id
    }
    MSectionHeader { key: "settings.fields.barRight" }
    MReorderList {
        Layout.fillWidth: true
        items: Config.bar.right || []
        labelKey: root.widgetKey
        onReordered: (next) => ConfigWrite.set("bar.right", next)
        onItemClicked: (id) => root.editorId = id
    }

    MSectionHeader { key: "settings.bar.available" }
    Repeater {
        model: root.catalog.length
        MListItem {
            required property int index
            readonly property string wid: String(root.catalog[index] || "")
            Layout.fillWidth: true
            titleKey: root.widgetKey(wid)
            onClicked: root.editorId = wid
            MSwitch {
                checked: root._enabled(wid)
                onToggled: (v) => root._toggle(wid, v)
            }
        }
    }
}
