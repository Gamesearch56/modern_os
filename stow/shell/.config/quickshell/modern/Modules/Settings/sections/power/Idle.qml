import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    readonly property var durations: [
        { value: 0, titleKey: "settings.energy.idleNever" },
        { value: 120, titleKey: "settings.energy.idleMin", params: ({ n: 2 }) },
        { value: 300, titleKey: "settings.energy.idleMin", params: ({ n: 5 }) },
        { value: 600, titleKey: "settings.energy.idleMin", params: ({ n: 10 }) },
        { value: 1800, titleKey: "settings.energy.idleMin", params: ({ n: 30 }) },
        { value: 3600, titleKey: "settings.energy.idleHour", params: ({ n: 1 }) },
        { value: 7200, titleKey: "settings.energy.idleHour", params: ({ n: 2 }) },
        { value: 14400, titleKey: "settings.energy.idleHour", params: ({ n: 4 }) },
        { value: 28800, titleKey: "settings.energy.idleHour", params: ({ n: 8 }) },
        { value: 43200, titleKey: "settings.energy.idleHour", params: ({ n: 12 }) }
    ]

    function _snap(sec: int): int {
        if (sec <= 0 || sec === 60)
            return 0;
        const opts = [0, 120, 300, 600, 1800, 3600, 7200, 14400, 28800, 43200];
        let best = opts[0];
        let d = Math.abs(sec - opts[0]);
        for (let i = 1; i < opts.length; i++) {
            const n = Math.abs(sec - opts[i]);
            if (n < d) {
                d = n;
                best = opts[i];
            }
        }
        return best;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.inhibitFullscreen"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.power.inhibitOnFullscreen)
            onToggled: (v) => ConfigWrite.set("power.inhibitOnFullscreen", v)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.inhibitMedia"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.power.inhibitOnMedia)
            onToggled: (v) => ConfigWrite.set("power.inhibitOnMedia", v)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.idleDim"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.durations
            value: root._snap(Config.general.idleTimings.dimSec ?? 120)
            onSelected: (v) => ConfigWrite.set("general.idleTimings.dimSec", Number(v))
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.idleOff"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.durations
            value: root._snap(Config.general.idleTimings.screenOffSec ?? 300)
            onSelected: (v) => ConfigWrite.set("general.idleTimings.screenOffSec", Number(v))
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.idleLock"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.durations
            value: root._snap(Config.general.idleTimings.lockSec ?? 600)
            onSelected: (v) => ConfigWrite.set("general.idleTimings.lockSec", Number(v))
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.idleSuspend"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 8
            model: root.durations
            value: root._snap(Config.general.idleTimings.suspendSec ?? 1800)
            onSelected: (v) => ConfigWrite.set("general.idleTimings.suspendSec", Number(v))
        }
    }
}
