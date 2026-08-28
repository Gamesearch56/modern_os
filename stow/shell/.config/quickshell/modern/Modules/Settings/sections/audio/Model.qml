import QtQuick
import "../../../../Commons"

QtObject {
    readonly property int masterVolumeLimit: Config.audio.masterVolumeLimit ?? 100
    readonly property string autoSwitchBluetooth: Config.audio.autoSwitchBluetooth ?? ""
}
