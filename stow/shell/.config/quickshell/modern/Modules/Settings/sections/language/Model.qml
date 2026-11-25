import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string ui: Config.language.ui ?? "en"
    readonly property int firstDayOfWeek: Config.language.firstDayOfWeek ?? 1
    readonly property string dateFormat: Config.language.dateFormat ?? ""
    readonly property string timeFormat: Config.language.timeFormat ?? ""
}
