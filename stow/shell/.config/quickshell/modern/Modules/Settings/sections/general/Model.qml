import QtQuick
import "../../../../Commons"

QtObject {
    readonly property real motionScale: Config.motion.scale ?? 1.0
    readonly property bool autologin: Config.general.autologin ?? false
    readonly property string idleText: JSON.stringify(Config.general.idleTimings || {})
}
