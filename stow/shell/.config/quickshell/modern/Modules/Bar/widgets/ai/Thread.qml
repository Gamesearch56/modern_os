import QtQuick
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root

    property bool _followEnd: true
    property bool _ownScroll: false
    property real _lastY: 0
    readonly property var _hist: Ai.history

    function scrollEnd() {
        root._followEnd = true;
        Qt.callLater(root._pinEnd);
    }

    function _endY(): real {
        return Math.max(0, flick.contentHeight - flick.height);
    }

    function _nearEnd(): bool {
        if (flick.height <= 0)
            return true;
        return flick.atYEnd || flick.contentY >= root._endY() - Tokens.spacing.xl;
    }

    // A list estimates row height, then the real text is shorter, and
    // the view is left below the last line. The column height is the text.
    function _pinEnd() {
        if (flick.height <= 0)
            return;
        const end = root._endY();
        const y = flick.contentY;
        let next = y;
        if (y > end)
            next = end;
        else if (root._followEnd && y < end - 1)
            next = end;
        if (Math.abs(next - y) < 1)
            return;
        root._ownScroll = true;
        flick.contentY = next;
        root._lastY = next;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(col.implicitHeight, height)
        boundsBehavior: Flickable.StopAtBounds
        visible: !root._empty

        Column {
            id: col
            width: flick.width
            spacing: Tokens.spacing.md

            Repeater {
                model: (root._hist || []).length
                delegate: MChatBubble {
                    required property int index
                    readonly property var row: (root._hist || [])[index] || ({})
                    width: col.width
                    mine: row.role === "user"
                    text: row.text || ""
                    thinking: row.thinking || ""
                    phase: row.phase || ""
                    pending: !!row.streaming
                }
            }
        }

        onContentHeightChanged: root._pinEnd()
        onHeightChanged: root._pinEnd()
        onContentYChanged: {
            const y = contentY;
            const up = y < root._lastY - 1;
            root._lastY = y;
            if (root._ownScroll) {
                root._ownScroll = false;
                return;
            }
            if (up || dragging || moving)
                root._followEnd = root._nearEnd();
            else if (root._nearEnd())
                root._followEnd = true;
        }
    }

    readonly property bool _blocked: (Config.accounts?.ai?.provider ?? "none") === "none" || !Ai.ready
    readonly property bool _empty: root._blocked || Ai.history.length === 0
    readonly property string _hintKey: {
        const provider = Config.accounts?.ai?.provider ?? "none";
        if (provider === "gemini")
            return "ai.hintGemini";
        if (provider === "chatgpt")
            return "ai.hintChatGpt";
        return "ai.hint";
    }

    MEmptyState {
        visible: root._empty
        anchors.fill: parent
        iconName: "applications-science-symbolic"
        titleKey: root._blocked ? "ai.needSetup" : "ai.empty"
        hintKey: root._blocked ? "" : root._hintKey
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
