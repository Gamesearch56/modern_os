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
        void Ai.panelOpen;
        void Ai.hostScreenName;
        return Ai.openOn(root.barScreen);
    }

    MIconButton {
        anchors.fill: parent
        iconName: "robot"
        key: "ai.title"
        checked: popup.open
        onClicked: Ai.toggle(root.barScreen)
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        elevation: 0
        implicitWidth: Tokens.spacing.xxl * 16
        implicitHeight: Tokens.spacing.xxl * 14
        onOpenChanged: {
            if (!popup.open && root._mine)
                Ai.hide();
        }
        onGrabReady: root._focusInput()

        Loader {
            id: panelLoader
            anchors.fill: parent
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                if (popup.open)
                    root._focusInput();
            }
        }
    }

    function _focusInput() {
        if (!popup.open)
            return;
        Qt.callLater(() => {
            if (!popup.open)
                return;
            if (panelLoader.item && panelLoader.item.focusInput)
                panelLoader.item.focusInput();
        });
    }

    Connections {
        target: Ai
        function onPanelOpenChanged() {
            root._sync();
        }
        function onHostScreenNameChanged() {
            root._sync();
        }
    }

    function _sync() {
        const mine = Ai.openOn(root.barScreen);
        if (popup.open !== mine)
            popup.open = mine;
    }

    Component.onCompleted: root._sync()
}
