import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string networkText: JSON.stringify(Config.network || {})
}
