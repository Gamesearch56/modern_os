import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string layoutText: JSON.stringify({
        left: Config.bar.left,
        center: Config.bar.center,
        right: Config.bar.right
    })
}
