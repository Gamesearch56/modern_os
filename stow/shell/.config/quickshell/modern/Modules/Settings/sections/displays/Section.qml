import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    property string selectedDesc: {
        const list = Hypr.monitors?.values ?? [];
        if (list.length > 0)
            return list[0].description || "";
        return "";
    }

    function _profile(): var {
        const all = Config.monitors?.profiles || ({});
        return all[root.selectedDesc] || ({});
    }

    MSectionHeader { key: "settings.fields.workspaceMode" }
    MSegmented {
        Layout.fillWidth: true
        value: Config.monitors?.workspaceMode || "fixed"
        model: [
            { value: "dynamic", titleKey: "settings.wsDynamic" },
            { value: "fixed", titleKey: "settings.wsFixed" }
        ]
        onSelected: (v) => ConfigWrite.set("monitors.workspaceMode", v)
    }
    MHint { key: "settings.hints.workspaceMode"; Layout.fillWidth: true }

    MSectionHeader { key: "settings.fields.monitors" }
    Repeater {
        model: Hypr.monitors?.values ?? []
        MListItem {
            required property var modelData
            Layout.fillWidth: true
            titleValue: modelData.description || modelData.name || ""
            subtitleValue: (modelData.width || "") + "×" + (modelData.height || "") + " @" + (modelData.scale || 1) + (modelData.refreshRate ? (" · " + Math.round(modelData.refreshRate) + " Hz") : "")
            selected: (modelData.description || "") === root.selectedDesc
            onClicked: root.selectedDesc = modelData.description || ""
        }
    }

    MField {
        visible: root.selectedDesc.length > 0
        labelKey: "settings.fields.scale"
        MSelect {
            value: String(root._profile().scale || 1)
            model: [
                { value: "1", titleValue: "100%" },
                { value: "1.1", titleValue: "110%" },
                { value: "1.25", titleValue: "125%" },
                { value: "1.5", titleValue: "150%" },
                { value: "2", titleValue: "200%" }
            ]
            onSelected: (v) => ConfigWrite.patchMonitor(root.selectedDesc, { scale: Number(v) })
        }
    }
    MListItem {
        visible: root.selectedDesc.length > 0
        Layout.fillWidth: true
        titleKey: "settings.fields.hdr"
        MSwitch {
            checked: !!(root._profile().hdr)
            onToggled: (v) => ConfigWrite.patchMonitor(root.selectedDesc, v ? {
                hdr: true,
                bitdepth: 10,
                cm: "hdr",
                sdrbrightness: 1,
                sdrsaturation: 0.9,
                sdr_eotf: "srgb",
                sdr_min_luminance: 0.005,
                sdr_max_luminance: 250,
                min_luminance: 0,
                supports_hdr: 1,
                supports_wide_color: 1
            } : {
                hdr: false,
                bitdepth: 8,
                cm: "srgb",
                supports_hdr: 0
            })
        }
    }
    MHint {
        visible: root.selectedDesc.length > 0
        key: "settings.hints.hdr"
        Layout.fillWidth: true
    }
    MListItem {
        visible: root.selectedDesc.length > 0
        Layout.fillWidth: true
        titleKey: "settings.fields.vrr"
        MSwitch {
            checked: !!(root._profile().vrr)
            onToggled: (v) => ConfigWrite.patchMonitor(root.selectedDesc, { vrr: v ? 1 : 0 })
        }
    }
}
