import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    property var barScreen: null
    implicitWidth: BarLayout.height
    implicitHeight: BarLayout.height

    readonly property bool _mine: {
        void Taskbar.open;
        void Taskbar.hostScreenName;
        void Taskbar.coverFullscreen;
        return Taskbar.openOn(root.barScreen);
    }
    readonly property bool _barPopup: root._mine && !Taskbar.coverFullscreen

    MIconButton {
        tabFocus: false
        anchors.fill: parent
        iconName: "focus-windows-symbolic"
        key: "bar.taskbar"
        checked: root._mine
        onClicked: Taskbar.toggle(root.barScreen)
    }

    BarLayerPopup {
        id: popup
        open: false
        anchorItem: root
        barScreen: root.barScreen
        elevation: 0
        panelWidth: Tokens.spacing.xxl * 14
        panelHeight: Tokens.spacing.xxl * 14
        hAlign: Qt.AlignRight
        onOpenChanged: {
            if (!popup.open) {
                root._grabFocused = false;
                if (root._barPopup)
                    Taskbar.hide();
            }
        }

        Connections {
            target: Taskbar
            function onOpenChanged() {
                root._sync();
            }
            function onHostScreenNameChanged() {
                root._sync();
            }
            function onCoverFullscreenChanged() {
                root._sync();
            }
        }

        Loader {
            id: panelLoader
            anchors.fill: parent
            source: Qt.resolvedUrl("Panel.qml")
            onLoaded: {
                if (item && item.barScreen !== undefined)
                    item.barScreen = Qt.binding(() => root.barScreen);
            }
        }
    }

    property bool _grabFocused: false

    Connections {
        target: popup
        function onGrabReady() {
            if (root._grabFocused)
                return;
            const p = panelLoader.item;
            if (!p || !p.focusFirst)
                return;
            root._grabFocused = true;
            p.focusFirst();
        }
    }

    function _sync() {
        const mine = root._barPopup;
        if (popup.open !== mine)
            popup.open = mine;
    }

    Component.onCompleted: root._sync()
}
