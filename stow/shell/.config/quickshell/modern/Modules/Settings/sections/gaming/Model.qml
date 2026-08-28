import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string gamingText: JSON.stringify(Config.gaming || {})
}
