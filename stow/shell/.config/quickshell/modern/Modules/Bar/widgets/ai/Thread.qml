import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root

    property bool _followEnd: true

    function scrollEnd() {
        root._followEnd = true;
        endSoon.restart();
    }

    Timer {
        id: endSoon
        interval: Motion.shortMs
        onTriggered: {
            if (!root._followEnd || list.count <= 0 || list.height <= 0)
                return;
            list.positionViewAtEnd();
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: Tokens.spacing.md
        boundsBehavior: Flickable.StopAtBounds
        visible: !root._empty
        model: Ai.history.length
        delegate: Item {
            required property int index
            readonly property var row: (Ai.history || [])[index] || ({})
            width: ListView.view.width
            implicitHeight: bubble.implicitHeight
            height: implicitHeight

            MChatBubble {
                id: bubble
                width: parent.width
                mine: row.role === "user"
                text: row.text || ""
                thinking: row.thinking || ""
                pending: !!row.streaming
            }
        }
        onCountChanged: {
            if (root._followEnd)
                endSoon.restart();
        }
        onContentHeightChanged: {
            if (root._followEnd)
                endSoon.restart();
        }
        onHeightChanged: {
            if (root._followEnd)
                endSoon.restart();
        }
        onMovementEnded: root._followEnd = list.atYEnd
        onFlickEnded: root._followEnd = list.atYEnd
    }

    readonly property bool _blocked: (Config.accounts?.ai?.provider ?? "none") === "none" || !Ai.ready
    readonly property bool _empty: root._blocked || Ai.history.length === 0

    MEmptyState {
        visible: root._empty
        anchors.fill: parent
        iconName: "applications-science-symbolic"
        titleKey: root._blocked ? "ai.needSetup" : "ai.empty"
        hintKey: root._blocked ? "" : "ai.hint"
        actionKey: root._blocked ? "ai.setup" : ""
        onActionClicked: {
            Ai.hide();
            Popups.dismiss();
            Settings.openAt("ai", "");
        }
    }

    Connections {
        target: Ai
        function onPanelOpenChanged() {
            if (Ai.panelOpen)
                root.scrollEnd();
        }
    }

    Component.onCompleted: root.scrollEnd()
}
