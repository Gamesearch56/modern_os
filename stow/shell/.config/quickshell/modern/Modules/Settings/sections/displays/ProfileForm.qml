import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    property string selectedDesc: ""

    spacing: Tokens.spacing.lg
    Layout.fillWidth: true
    visible: root.selectedDesc.length > 0

    readonly property var mon: {
        void Hypr.monitorGen;
        return Hypr.monitorByDesc(root.selectedDesc);
    }
    readonly property var profile: {
        void Config.monitors;
        const all = Config.monitors?.profiles || ({});
        return all[root.selectedDesc] || ({});
    }
    readonly property var parsedMode: Hypr.parseMode(String(root.profile.mode || ""))
    readonly property int widthPx: root.parsedMode ? root.parsedMode.w : Number(root.mon?.width || 0)
    readonly property int heightPx: root.parsedMode ? root.parsedMode.h : Number(root.mon?.height || 0)
    readonly property real hzNow: {
        void Hypr.monitorGen;
        return root.parsedMode ? root.parsedMode.hz : Number(Hypr.hzFor(root.mon));
    }
    readonly property var resolutions: {
        void Hypr.monitorGen;
        return Hypr.resolutionsFor(root.mon);
    }
    readonly property var rates: {
        void Hypr.monitorGen;
        return Hypr.ratesFor(root.mon, root.widthPx, root.heightPx);
    }
    readonly property bool hdrOn: !!(root.profile.hdr)

    function patch(extra: var) {
        ConfigWrite.patchMonitor(root.selectedDesc, extra);
    }

    function setMode(w: int, h: int, preferHz: real) {
        const mode = Hypr.bestMode(root.mon, w, h, preferHz);
        if (!mode.length)
            return;
        root.patch({ mode: mode });
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.hdr"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: root.hdrOn
            onToggled: (v) => root.patch(v ? {
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

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.vrr"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(root.profile.vrr)
            onToggled: (v) => root.patch({ vrr: v ? 1 : 0 })
        }
    }

    MField {
        visible: root.resolutions.length > 1
        labelKey: "settings.fields.resolution"
        MSelect {
            value: root.widthPx && root.heightPx ? (root.widthPx + "x" + root.heightPx) : ""
            model: root.resolutions
            onSelected: (v) => {
                const parts = String(v).split("x");
                if (parts.length !== 2)
                    return;
                root.setMode(Number(parts[0]), Number(parts[1]), root.hzNow);
            }
        }
    }

    MField {
        visible: root.rates.length > 1
        labelKey: "settings.fields.displayRefresh"
        MSelect {
            value: {
                const list = root.rates;
                const want = Number(root.hzNow);
                for (let i = 0; i < list.length; i++) {
                    if (Math.abs(list[i].hz - want) < 0.6)
                        return list[i].value;
                }
                return list.length ? list[0].value : "";
            }
            model: root.rates
            onSelected: (v) => root.setMode(root.widthPx, root.heightPx, Number(v))
        }
    }

    MField {
        labelKey: "settings.fields.scale"
        MSelect {
            value: String(root.profile.scale || 1)
            model: [
                { value: "1", titleValue: "100%" },
                { value: "1.1", titleValue: "110%" },
                { value: "1.25", titleValue: "125%" },
                { value: "1.5", titleValue: "150%" },
                { value: "2", titleValue: "200%" }
            ]
            onSelected: (v) => root.patch({ scale: Number(v) })
        }
    }

    MField {
        visible: Brightness.canControl(root.selectedDesc)
        labelKey: "quickSettings.brightness"
        MSlider {
            from: 1
            to: 100
            value: Brightness.percentFor(root.selectedDesc)
            showValue: true
            suffix: "%"
            onMoved: (v) => Brightness.setFor(root.selectedDesc, Math.round(v))
        }
    }

    MField {
        visible: !root.hdrOn
        labelKey: "settings.fields.colorProfile"
        MSelect {
            value: String(root.profile.cm || "srgb")
            model: [
                { value: "srgb", titleKey: "settings.cmSrgb" },
                { value: "wide", titleKey: "settings.cmWide" },
                { value: "edid", titleKey: "settings.cmEdid" }
            ]
            onSelected: (v) => root.patch({ cm: v })
        }
    }
}
