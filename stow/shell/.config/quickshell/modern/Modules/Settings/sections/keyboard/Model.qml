import QtQuick
import "../../../../Commons"
import "../../../../Services"

QtObject {
    readonly property var rows: CheatsheetModel.rows("")
    readonly property string kbLayout: Config.input.kbLayout ?? "de"
}
