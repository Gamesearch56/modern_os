import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    property var barScreen: null
    implicitWidth: Config.bar.height
    implicitHeight: Config.bar.height

    readonly property bool _mine: {
        void Taskbar.open;
        void Taskbar.hostScreenName;
        return Taskbar.openOn(root.barScreen);
    }

    MIconButton {
        anchors.fill: parent
        iconName: "focus-windows-symbolic"
        key: "bar.taskbar"
        checked: root._mine
        onClicked: Taskbar.toggle(root.barScreen)
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        elevation: 0
        implicitWidth: Tokens.spacing.xxl * 14
        implicitHeight: Tokens.spacing.xxl * 14
        hAlign: Qt.AlignRight
        onOpenChanged: {
            if (!popup.open && root._mine)
                Taskbar.hide();
        }

        Connections {
            target: Taskbar
            function onOpenChanged() {
                root._sync();
            }
            function onHostScreenNameChanged() {
                root._sync();
            }
        }

        Loader {
            anchors.fill: parent
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                if (item && item.barScreen !== undefined)
                    item.barScreen = Qt.binding(() => root.barScreen);
            }
        }
    }

    function _sync() {
        const mine = Taskbar.openOn(root.barScreen);
        if (popup.open !== mine)
            popup.open = mine;
    }

    Component.onCompleted: root._sync()
}
