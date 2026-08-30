import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Model { id: barModel }
    property string editorId: ""
    readonly property bool editorOpen: root.editorId.length > 0

    readonly property var catalog: [
        "launcher", "ai", "workspaces", "media", "taskbar", "clock",
        "weather", "connectivity", "audio", "battery", "settings", "power"
    ]

    function widgetKey(id) {
        return barModel.key(id);
    }

    function _in(arr, id) {
        const list = arr || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] === id)
                return true;
        }
        return false;
    }

    function _writeBar(patch) {
        let bar = {
            position: Config.bar.position || "top",
            style: Config.bar.style || "floating",
            height: Config.bar.height || 36,
            edgeGap: Config.bar.edgeGap ?? 8,
            endGap: Config.bar.endGap ?? 8,
            autoHide: !!(Config.bar.autoHide),
            left: (Config.bar.left || []).slice(),
            center: (Config.bar.center || []).slice(),
            right: (Config.bar.right || []).slice()
        };
        try {
            const raw = JSON.parse(JSON.stringify(Config.bar || {}));
            if (raw && typeof raw === "object")
                bar = Object.assign(bar, raw);
        } catch (e) {
        }
        Object.assign(bar, patch);
        bar.perMonitor = { enabled: !!(Config.bar.perMonitor?.enabled !== false) };
        ConfigWrite.set("bar", bar);
    }

    function _toggle(id, on) {
        if (on) {
            if (root._in(Config.bar.left, id) || root._in(Config.bar.center, id) || root._in(Config.bar.right, id))
                return;
            const next = (Config.bar.left || []).slice();
            next.push(id);
            root._writeBar({ left: next });
            return;
        }
        const left = [];
        const center = [];
        const right = [];
        const src = [
            { from: Config.bar.left, to: left },
            { from: Config.bar.center, to: center },
            { from: Config.bar.right, to: right }
        ];
        for (let s = 0; s < src.length; s++) {
            const cur = src[s].from || [];
            for (let i = 0; i < cur.length; i++) {
                if (cur[i] !== id)
                    src[s].to.push(cur[i]);
            }
        }
        root._writeBar({ left: left, center: center, right: right });
    }

    function _configurable(id) {
        return id === "weather" || id === "clock" || id === "audio";
    }

    function _enabled(id) {
        return root._in(Config.bar.left, id) || root._in(Config.bar.center, id) || root._in(Config.bar.right, id);
    }

    MSectionHeader {
        key: "settings.fields.barPosition"
        topMargin: 0
    }
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

    MSectionHeader {
        key: "settings.fields.barStyle"
        topMargin: Tokens.spacing.xxl
    }
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
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.autoHide"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.bar.autoHide)
            onToggled: (v) => ConfigWrite.set("bar.autoHide", v)
        }
    }

    MSectionHeader {
        key: "settings.fields.widgetsPosition"
        topMargin: Tokens.spacing.xxl
    }
    MSlotBoard {
        Layout.fillWidth: true
        leftItems: Config.bar.left || []
        centerItems: Config.bar.center || []
        rightItems: Config.bar.right || []
        leftTitleKey: "settings.fields.barLeft"
        centerTitleKey: "settings.fields.barCenter"
        rightTitleKey: "settings.fields.barRight"
        labelKey: root.widgetKey
        iconName: barModel.icon
        configurable: root._configurable
        onSlotsChanged: (left, center, right) => root._writeBar({ left: left, center: center, right: right })
        onItemClicked: (id) => root.editorId = id
    }

    MSectionHeader {
        key: "settings.bar.available"
        topMargin: Tokens.spacing.xxl
    }
    Repeater {
        model: root.catalog.length
        MListItem {
            required property int index
            readonly property string wid: String(root.catalog[index] || "")
            Layout.fillWidth: true
            titleKey: root.widgetKey(wid)
            iconName: barModel.icon(wid)
            hoverHighlight: root._configurable(wid)
            badgeIcon: root._configurable(wid) ? "document-edit-symbolic" : ""
            onClicked: {
                if (root._configurable(wid))
                    root.editorId = wid;
            }
            MSwitch {
                checked: root._enabled(wid)
                onToggled: (v) => root._toggle(wid, v)
            }
        }
    }
}
