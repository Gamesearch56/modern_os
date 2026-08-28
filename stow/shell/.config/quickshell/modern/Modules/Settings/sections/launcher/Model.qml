import QtQuick
import "../../../../Commons"

QtObject {
    readonly property int resultCount: Config.launcher.resultCount ?? 9
    readonly property bool frecencyEnabled: Config.launcher.frecencyEnabled ?? true
    readonly property string providersText: JSON.stringify(Config.launcher.providers || {})
}
