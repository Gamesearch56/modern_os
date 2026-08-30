import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string directory: Config.screenshots.directory ?? ""
    readonly property string format: Config.screenshots.format ?? "png"
    readonly property int quality: Config.screenshots.quality ?? 90
    readonly property bool copyToClipboard: Config.screenshots.copyToClipboard ?? true
    readonly property bool openEditorAfterCapture: Config.screenshots.openEditorAfterCapture ?? false
    readonly property bool includeCursor: Config.screenshots.includeCursor ?? false
}
