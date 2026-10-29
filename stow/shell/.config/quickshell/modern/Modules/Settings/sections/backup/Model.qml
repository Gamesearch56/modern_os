import QtQuick
import "../../../../Commons"

QtObject {
    readonly property bool preUpdateSnapshot: Config.backup.preUpdateSnapshot ?? true
    readonly property bool pruneEnabled: Config.backup.pruneEnabled ?? true
    readonly property int keepCount: Config.backup.keepCount ?? 8
}
