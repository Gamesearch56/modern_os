import QtQuick
import "../../../../Commons"

QtObject {
    readonly property int masterVolumeLimit: Config.audio.masterVolumeLimit ?? 100
    readonly property bool autoBluetooth: (Config.audio.autoSwitchBluetooth || "on") === "on"
    readonly property string fallbackSink: String(Config.audio.fallbackSink || "")
    readonly property string fallbackSource: String(Config.audio.fallbackSource || "")
}
