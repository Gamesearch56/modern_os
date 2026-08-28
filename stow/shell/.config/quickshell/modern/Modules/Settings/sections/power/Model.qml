import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string buttonAction: Config.power.buttonAction ?? ""
    readonly property string lidActionAc: Config.power.lidActionAc ?? ""
    readonly property string lidActionBattery: Config.power.lidActionBattery ?? ""
}
