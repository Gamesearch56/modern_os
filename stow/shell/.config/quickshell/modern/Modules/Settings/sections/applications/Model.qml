import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string autostartText: JSON.stringify(Config.general.autostart || [])
}
