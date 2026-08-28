import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    readonly property var lidActions: [
        { value: "ask", titleKey: "settings.powerAsk" },
        { value: "suspend", titleKey: "powerMenu.suspend" },
        { value: "lock", titleKey: "powerMenu.lock" },
        { value: "poweroff", titleKey: "powerMenu.poweroff" }
    ]

    MField {
        labelKey: "settings.fields.buttonAction"
        MSelect {
            model: root.lidActions
            value: Config.power.buttonAction
            onSelected: (v) => ConfigWrite.set("power.buttonAction", v)
        }
    }
    MField {
        labelKey: "settings.fields.lidAc"
        MSelect {
            model: root.lidActions
            value: Config.power.lidActionAc
            onSelected: (v) => ConfigWrite.set("power.lidActionAc", v)
        }
    }
    MField {
        labelKey: "settings.fields.lidBattery"
        MSelect {
            model: root.lidActions
            value: Config.power.lidActionBattery
            onSelected: (v) => ConfigWrite.set("power.lidActionBattery", v)
        }
    }
}
