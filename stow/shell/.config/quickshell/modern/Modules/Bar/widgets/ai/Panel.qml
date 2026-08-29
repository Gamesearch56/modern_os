import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

Item {
    id: root

    readonly property bool _off: (Config.accounts?.ai?.provider ?? "ollama") === "none"

    function send() {
        if (root._off || Ai.busy)
            return;
        const t = field.text.trim();
        if (!t.length)
            return;
        Ai.chat(t);
        field.text = "";
        Qt.callLater(root._scrollEnd);
    }

    function _scrollEnd() {
        flick.contentY = Math.max(0, col.implicitHeight - flick.height);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            MText {
                key: "ai.title"
                styleName: "headlineMedium"
                Layout.fillWidth: true
            }
            MButton {
                kind: "text"
                key: "ai.clear"
                enabled: Ai.history.length > 0
                onClicked: Ai.clear()
            }
            MIconButton {
                close: true
                iconName: "window-close"
                key: "bar.close"
                onClicked: Popups.dismiss()
            }
        }

        MPane {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: col.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                visible: !root._off && Ai.history.length > 0

                ColumnLayout {
                    id: col
                    width: flick.width
                    spacing: Tokens.spacing.xxs

                    Repeater {
                        model: Ai.history.length
                        delegate: ColumnLayout {
                            required property int index
                            readonly property var row: Ai.history[index] || ({})
                            readonly property bool mine: row.role === "user"
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.xxs

                            MText {
                                key: mine ? "ai.you" : "ai.assistant"
                                styleName: "labelSmall"
                                color: Colors.color.onSurfaceVariant
                                font.capitalization: Font.AllUppercase
                                Layout.fillWidth: true
                            }
                            MText {
                                value: row.text || ""
                                styleName: "bodyMedium"
                                wrapMode: Text.WordWrap
                                elide: Text.ElideNone
                                lineHeightMode: Text.ProportionalHeight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MHint {
                        visible: Ai.busy
                        key: "ai.thinking"
                    }
                }
            }

            MEmptyState {
                visible: root._off || Ai.history.length === 0
                anchors.fill: parent
                iconName: "help-about-symbolic"
                titleKey: root._off ? "ai.disabled" : "ai.empty"
                hintKey: root._off ? "ai.enableHint" : "ai.hint"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm

            MTextField {
                id: field
                Layout.fillWidth: true
                enabled: !root._off && !Ai.busy
                placeholderKey: "ai.placeholder"
                onAccepted: root.send()
            }
            MButton {
                kind: "filled"
                key: "ai.send"
                enabled: !root._off && !Ai.busy && field.text.trim().length > 0
                onClicked: root.send()
            }
        }
    }

    Connections {
        target: Ai
        function onHistoryChanged() {
            Qt.callLater(root._scrollEnd);
        }
    }
}
