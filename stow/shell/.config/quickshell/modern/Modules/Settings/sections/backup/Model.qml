import QtQuick
import "../../../../Commons"

QtObject {
    readonly property bool snapperEnabled: Config.backup.snapperEnabled ?? false
    readonly property bool preUpdateSnapshot: Config.backup.preUpdateSnapshot ?? true
}
