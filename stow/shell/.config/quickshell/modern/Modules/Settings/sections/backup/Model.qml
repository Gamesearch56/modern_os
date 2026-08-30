import QtQuick
import "../../../../Commons"

QtObject {
    readonly property bool preUpdateSnapshot: Config.backup.preUpdateSnapshot ?? true
}
