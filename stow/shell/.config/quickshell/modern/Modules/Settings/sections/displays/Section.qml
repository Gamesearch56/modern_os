import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    property string selectedDesc: ""

    readonly property int _n: {
        void Hypr.monitors;
        void Hypr.monitorGen;
        return (Hypr.monitors?.values ?? []).length;
    }

    function _ensureSelection() {
        const list = Hypr.monitors?.values ?? [];
        let found = false;
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].description || "") === root.selectedDesc) {
                found = true;
                break;
            }
        }
        if (!found)
            root.selectedDesc = list.length ? String(list[0].description || "") : "";
    }

    on_NChanged: {
        root._ensureSelection();
        Brightness.refreshDisplays();
    }
    Component.onCompleted: {
        Hypr.refreshMonitorDump();
        Brightness.refreshDisplays();
        root._ensureSelection();
    }

    MField {
        labelKey: "settings.fields.workspaceMode"
        hintKey: "settings.hints.workspaceMode"
        MSegmented {
            value: Config.monitors?.workspaceMode || "dynamic"
            model: [
                { value: "dynamic", titleKey: "settings.wsDynamic" },
                { value: "fixed", titleKey: "settings.wsFixed" }
            ]
            onSelected: (v) => ConfigWrite.set("monitors.workspaceMode", v)
        }
    }

    MField {
        visible: root._n > 0
        labelKey: "settings.fields.monitors"
        Layout.topMargin: Tokens.spacing.xxl
        ProfileList {
            selectedDesc: root.selectedDesc
            onPicked: (desc) => {
                root.selectedDesc = desc;
            }
        }
    }

    ProfileForm {
        selectedDesc: root.selectedDesc
    }
}
