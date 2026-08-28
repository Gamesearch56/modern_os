import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MSectionHeader { key: "settings.fields.autologin" }
    MListItem {
        Layout.fillWidth: true
        titleKey: "settings.fields.autologin"
        enabled: false
        MSwitch {
            checked: Config.general.autologin
            enabled: false
        }
    }
    MHint { key: "settings.gated"; Layout.fillWidth: true }

    MSectionHeader { key: "settings.fields.idleTimings" }
    MField {
        labelKey: "settings.fields.idleDim"
        MTextField {
            text: String(Config.general.idleTimings.dimSec)
            onAccepted: ConfigWrite.set("general.idleTimings.dimSec", Number(text))
        }
    }
    MField {
        labelKey: "settings.fields.idleOff"
        MTextField {
            text: String(Config.general.idleTimings.screenOffSec)
            onAccepted: ConfigWrite.set("general.idleTimings.screenOffSec", Number(text))
        }
    }
    MField {
        labelKey: "settings.fields.idleLock"
        MTextField {
            text: String(Config.general.idleTimings.lockSec)
            onAccepted: ConfigWrite.set("general.idleTimings.lockSec", Number(text))
        }
    }
    MField {
        labelKey: "settings.fields.idleSuspend"
        MTextField {
            text: String(Config.general.idleTimings.suspendSec)
            onAccepted: ConfigWrite.set("general.idleTimings.suspendSec", Number(text))
        }
    }
}
