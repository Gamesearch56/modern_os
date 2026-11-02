import QtQuick
import "../../../../Commons"

QtObject {
    readonly property bool autoFullscreen: Config.gaming.autoFullscreen !== false
    readonly property bool autoOptimize: Config.gaming.autoOptimize !== false
    readonly property bool hdrSession: Config.gaming.hdrSession === true
    readonly property bool browserLight: Config.gaming.browserLight === true
}
