import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string kbLayout: Config.input.kbLayout ?? "de"
}
