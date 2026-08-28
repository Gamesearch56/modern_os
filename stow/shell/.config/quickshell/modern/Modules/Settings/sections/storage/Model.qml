import QtQuick
import "../../../../Commons"

QtObject {
    readonly property bool snapperEnabled: Config.backup.snapperEnabled ?? false
    readonly property bool resticEnabled: Config.backup.resticEnabled ?? false
    readonly property bool preUpdateSnapshot: Config.backup.preUpdateSnapshot ?? true
}
