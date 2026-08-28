import QtQuick
import "../../../../Commons"

QtObject {
    readonly property real motionScale: Config.motion.scale ?? 1.0
    readonly property bool autologin: Config.general.autologin ?? false
    readonly property string idleText: {
        const t = Config.general.idleTimings;
        if (!t)
            return "";
        return String(t.dimSec) + " / " + String(t.screenOffSec) + " / " + String(t.lockSec) + " / " + String(t.suspendSec);
    }
}
