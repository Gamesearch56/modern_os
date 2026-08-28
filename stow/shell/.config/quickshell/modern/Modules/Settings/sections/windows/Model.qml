import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string rulesText: JSON.stringify(Config.windowRules || [])
}
