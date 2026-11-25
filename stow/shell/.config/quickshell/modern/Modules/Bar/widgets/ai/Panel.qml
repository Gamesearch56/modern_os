import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "../../"

Item {
    id: root
    anchors.fill: parent

    readonly property bool _blocked: (Config.accounts?.ai?.provider ?? "none") === "none" || !Ai.ready
    readonly property bool _live: {
        void Ai.history;
        const list = Ai.history || [];
        return Ai.busy || !!(list.length && list[list.length - 1] && list[list.length - 1].streaming);
    }

    function focusInput() {
        if (root._blocked)
            return;
        field.focusInput();
    }

    function send() {
        if (root._blocked || root._live)
            return;
        const t = field.text.trim();
        if (!t.length)
            return;
        Ai.chat(t);
        field.text = "";
        Qt.callLater(() => {
            root._scrollEnd();
            root.focusInput();
        });
    }

    function _scrollEnd() {
        if (threadLoader.item && threadLoader.item.scrollEnd)
            threadLoader.item.scrollEnd();
    }

    function _openSettings() {
        Ai.hide();
        Popups.dismiss();
        Settings.openAt("ai", "");
    }

    Connections {
        target: Ai
        function onCancelled(text) {
            const t = String(text || "");
            if (t.length)
                field.text = t;
            root.focusInput();
        }
    }

    BarPanelChrome {
        id: chrome
        anchors.fill: parent
        titleKey: "ai.title"

        actions: RowLayout {
            spacing: Tokens.spacing.xs

            MButton {
                kind: "text"
                key: "ai.clear"
                enabled: Ai.history.length > 0 && !root._live
                onClicked: Ai.clear()
            }
            MIconButton {
                iconName: "preferences-system-symbolic"
                key: "ai.settings"
                onClicked: root._openSettings()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: threadLoader
                anchors.fill: parent
                source: Qt.resolvedUrl("Thread.qml")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            MTextField {
                id: field
                Layout.fillWidth: true
                enabled: !root._blocked
                placeholderKey: "ai.placeholder"
                maximumLength: 2000
                escapeCloses: true
                onAccepted: root.send()
                onEscaped: Ai.hide()
            }
            MButton {
                kind: "outlined"
                key: "ai.stop"
                visible: root._live
                onClicked: Ai.cancel()
            }
            MButton {
                kind: "filled"
                key: "ai.send"
                visible: !root._live
                enabled: !root._blocked && field.text.trim().length > 0
                onClicked: root.send()
            }
        }
    }
}
