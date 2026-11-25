import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string activeProfile: Config.design.activeProfile ?? ""
    readonly property real transparency: Config.design.transparency ?? 0.85
    readonly property real cornerRounding: Config.design.cornerRounding ?? 1.0
    readonly property string wallpaperProvider: Config.design.wallpaperProvider ?? ""
}
