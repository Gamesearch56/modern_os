import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string dndText: JSON.stringify(Config.general.dndSchedule || {})
    readonly property string kdeconnectText: JSON.stringify({
        enabled: Config.kdeconnect.enabled,
        mirrorNotifications: Config.kdeconnect.mirrorNotifications,
        sharedClipboard: Config.kdeconnect.sharedClipboard
    })
}
