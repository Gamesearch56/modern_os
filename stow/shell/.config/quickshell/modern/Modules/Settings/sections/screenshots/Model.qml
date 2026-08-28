import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string directory: Config.screenshots.directory ?? ""
    readonly property string format: Config.screenshots.format ?? ""
    readonly property bool copyToClipboard: Config.screenshots.copyToClipboard ?? true
}
