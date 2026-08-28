import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    readonly property var catalog: [
        "launcher", "ai", "workspaces", "media", "tray", "taskbar",
        "clock", "weather", "connectivity", "network", "bluetooth",
        "audio", "battery", "settings", "power", "notifications"
    ]

    function _in(arr, id) {
        const list = arr || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] === id)
                return true;
        }
        return false;
    }

    function _toggle(slot, id, on) {
        const cur = (Config.bar[slot] || []).slice();
        const next = [];
        for (let i = 0; i < cur.length; i++) {
            if (cur[i] !== id)
                next.push(cur[i]);
        }
        if (on)
            next.push(id);
        ConfigWrite.set("bar." + slot, next);
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

    MSectionHeader { key: "settings.fields.barLeft" }
    Repeater {
        model: root.catalog
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleKey: "bar." + modelData
            MSwitch {
                checked: root._in(Config.bar.left, modelData)
                onToggled: (v) => root._toggle("left", modelData, v)
            }
        }
    }
    MSectionHeader { key: "settings.fields.barCenter" }
    Repeater {
        model: root.catalog
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleKey: "bar." + modelData
            MSwitch {
                checked: root._in(Config.bar.center, modelData)
                onToggled: (v) => root._toggle("center", modelData, v)
            }
        }
    }
    MSectionHeader { key: "settings.fields.barRight" }
    Repeater {
        model: root.catalog
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleKey: "bar." + modelData
            MSwitch {
                checked: root._in(Config.bar.right, modelData)
                onToggled: (v) => root._toggle("right", modelData, v)
            }
        }
    }
}
