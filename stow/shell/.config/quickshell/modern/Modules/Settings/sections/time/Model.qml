import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string dateFormat: Config.language.dateFormat ?? ""
    readonly property string timeFormat: Config.language.timeFormat ?? ""
    readonly property int firstDayOfWeek: Config.language.firstDayOfWeek ?? 1
}
