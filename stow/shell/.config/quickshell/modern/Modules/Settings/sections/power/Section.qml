import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Component.onCompleted: Battery.watch()
    Component.onDestruction: Battery.unwatch()

    readonly property var lidActions: [
        { value: "ask", titleKey: "settings.powerAsk" },
        { value: "suspend", titleKey: "powerMenu.suspend" },
        { value: "lock", titleKey: "powerMenu.lock" },
        { value: "poweroff", titleKey: "powerMenu.poweroff" }
    ]

    MSectionHeader {
        visible: Battery.hasBattery
        key: "settings.energy.battery"
        topMargin: 0
    }
    Status {
        Layout.fillWidth: true
    }
    Stats {
        Layout.fillWidth: true
    }
    Facts {
        Layout.fillWidth: true
    }

    MSectionHeader {
        key: "settings.energy.idle"
        topMargin: Battery.hasBattery ? Tokens.spacing.xl : 0
    }
    Idle {
        Layout.fillWidth: true
    }

    MSectionHeader {
        key: "settings.energy.power"
        topMargin: Tokens.spacing.xl
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.buttonAction"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.lidActions
            value: Config.power.buttonAction
            onSelected: (v) => ConfigWrite.set("power.buttonAction", v)
        }
    }
    RowLayout {
        visible: Battery.hasBattery
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.lidAc"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.lidActions
            value: Config.power.lidActionAc
            onSelected: (v) => ConfigWrite.set("power.lidActionAc", v)
        }
    }
    RowLayout {
        visible: Battery.hasBattery
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.lidBattery"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.lidActions
            value: Config.power.lidActionBattery
            onSelected: (v) => ConfigWrite.set("power.lidActionBattery", v)
        }
    }
}
