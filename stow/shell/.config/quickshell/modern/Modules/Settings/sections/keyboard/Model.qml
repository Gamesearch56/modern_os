import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string kbLayout: Config.input.kbLayout ?? "us"
    readonly property var options: KeyboardLayouts.options
}
