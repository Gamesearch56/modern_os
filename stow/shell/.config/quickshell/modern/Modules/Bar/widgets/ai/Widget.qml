import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    property var barScreen: null
    implicitWidth: icon.implicitWidth + Tokens.spacing.md * 2
    implicitHeight: Config.bar.height

    readonly property bool _mine: {
        void Ai.panelOpen;
        void Ai.hostScreenName;
        void Ai.coverFullscreen;
        return Ai.openOn(root.barScreen);
    }
    readonly property bool _barPopup: root._mine && !Ai.coverFullscreen
    readonly property color _fg: root._mine ? Colors.color.onPrimaryContainer : Colors.color.onSurface

    BarIslandHit {
        checked: root._mine
        onClicked: Ai.toggle(root.barScreen)
    }

    MIcon {
        id: icon
        anchors.centerIn: parent
        z: 1
        name: "applications-science-symbolic"
        size: Tokens.icon.md
        color: root._fg
    }

    BarPopup {
        id: popup
        open: false
        anchorItem: root
        elevation: 0
        implicitWidth: Tokens.window.chatWidth
        implicitHeight: Tokens.window.chatHeight
        hAlign: Qt.AlignLeft
        onOpenChanged: {
            if (!popup.open && root._barPopup)
                Ai.hide();
        }
        onGrabReady: {
            if (panelLoader.item && panelLoader.item.focusInput)
                panelLoader.item.focusInput();
            if (panelLoader.item && panelLoader.item._scrollEnd)
                panelLoader.item._scrollEnd();
        }

        Connections {
            target: Ai
            function onPanelOpenChanged() {
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
        }
    }

    function _sync() {
        const mine = root._barPopup;
        if (popup.open !== mine)
            popup.open = mine;
    }

    Component.onCompleted: root._sync()
}
