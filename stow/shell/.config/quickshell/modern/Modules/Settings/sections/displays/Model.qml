import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string monitorsText: JSON.stringify(Config.monitors || {})
}
