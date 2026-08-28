import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string accountsText: JSON.stringify(Config.accounts || {})
}
