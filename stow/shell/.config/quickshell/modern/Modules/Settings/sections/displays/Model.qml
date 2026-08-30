import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string workspaceMode: Config.monitors?.workspaceMode || "dynamic"
}
