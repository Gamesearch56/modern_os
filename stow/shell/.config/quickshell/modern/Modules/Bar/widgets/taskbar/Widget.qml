import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    property var barScreen: null
    implicitWidth: Tokens.spacing.xxl
    implicitHeight: Tokens.spacing.xxl

    MIconButton {
        anchors.centerIn: parent
        iconName: "focus-windows-symbolic"
        key: "bar.taskbar"
        checked: popup.open
        onClicked: popup.open = !popup.open
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        elevation: 0
        implicitWidth: Tokens.spacing.xxl * 14
        implicitHeight: Tokens.spacing.xxl * 14
        hAlign: Qt.AlignRight

        Loader {
            anchors.fill: parent
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                if (item && item.barScreen !== undefined)
                    item.barScreen = Qt.binding(() => root.barScreen);
            }
        }
    }
}
