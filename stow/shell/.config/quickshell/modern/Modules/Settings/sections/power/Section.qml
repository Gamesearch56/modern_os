import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.md

    Component.onCompleted: {
        Battery.watching = true;
        SystemStats.watching = true;
    }
    Component.onDestruction: {
        Battery.watching = false;
        SystemStats.watching = false;
    }

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

    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.inhibitFullscreen"
        MSwitch {
            checked: !!(Config.power.inhibitOnFullscreen)
            onToggled: (v) => ConfigWrite.set("power.inhibitOnFullscreen", v)
        }
    }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.inhibitMedia"
        MSwitch {
            checked: !!(Config.power.inhibitOnMedia)
            onToggled: (v) => ConfigWrite.set("power.inhibitOnMedia", v)
        }
    }

    MSectionHeader { key: "settings.fields.idleTimings" }
    MField {
        labelKey: "settings.fields.idleDim"
        MSlider {
            from: 30
            to: 600
            value: Config.general.idleTimings.dimSec ?? 120
            showValue: true
            onMoved: (v) => ConfigWrite.set("general.idleTimings.dimSec", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.idleOff"
        MSlider {
            from: 60
            to: 1800
            value: Config.general.idleTimings.screenOffSec ?? 300
            showValue: true
            onMoved: (v) => ConfigWrite.set("general.idleTimings.screenOffSec", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.idleLock"
        MSlider {
            from: 60
            to: 3600
            value: Config.general.idleTimings.lockSec ?? 600
            showValue: true
            onMoved: (v) => ConfigWrite.set("general.idleTimings.lockSec", Math.round(v))
        }
    }
    MField {
        labelKey: "settings.fields.idleSuspend"
        MSlider {
            from: 300
            to: 7200
            value: Config.general.idleTimings.suspendSec ?? 1800
            showValue: true
            onMoved: (v) => ConfigWrite.set("general.idleTimings.suspendSec", Math.round(v))
        }
    }

    MSectionHeader { key: "settings.energyNow" }
    MText {
        visible: Battery.onBattery
        key: "settings.energyBattery"
        params: ({ n: Battery.percent })
        styleName: "labelLarge"
    }
    MSparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl + Tokens.spacing.md
        values: Battery.onBattery ? Battery.percentSamples : SystemStats.cpuSamples
        fillColor: Battery.onBattery ? Colors.color.tertiary : Colors.color.primary
    }
}
