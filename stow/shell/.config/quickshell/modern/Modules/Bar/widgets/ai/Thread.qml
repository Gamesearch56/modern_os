import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root

    function scrollEnd() {
        if (list.count <= 0)
            return;
        list.positionViewAtEnd();
        Qt.callLater(() => list.positionViewAtEnd());
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
        onCountChanged: root.scrollEnd()
        onContentHeightChanged: {
            if (Ai.busy && list.atYEnd)
                root.scrollEnd();
        }
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
                Qt.callLater(root.scrollEnd);
        }
    }

    Component.onCompleted: Qt.callLater(root.scrollEnd)
}
