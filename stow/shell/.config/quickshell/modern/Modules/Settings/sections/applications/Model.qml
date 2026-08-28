import QtQuick
import "../../../../Commons"

QtObject {
    readonly property var autostart: Config.general.autostart || []
}
