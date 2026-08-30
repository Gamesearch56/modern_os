import QtQuick
import "../../../../Commons"

QtObject {
    readonly property int masterVolumeLimit: Config.audio.masterVolumeLimit ?? 100
    readonly property bool autoBluetooth: (Config.audio.autoSwitchBluetooth || "on") !== "off"
}
