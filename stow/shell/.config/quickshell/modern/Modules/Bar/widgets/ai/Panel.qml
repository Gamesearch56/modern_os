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
        Ai.chat(field.text);
        field.text = "";
        Qt.callLater(root._scrollEnd);
    }

    function _scrollEnd() {
        flick.contentY = Math.max(0, col.implicitHeight - flick.height);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            MText {
                key: "ai.title"
                styleName: "headlineSmall"
                Layout.fillWidth: true
            }
            MIconButton {
                iconName: "edit-clear-symbolic"
                key: "ai.clear"
                enabled: Ai.history.length > 0
                onClicked: Ai.clear()
            }
        }

        Item {
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
                    spacing: Tokens.spacing.sm

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
                                Layout.alignment: mine ? Qt.AlignRight : Qt.AlignLeft
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.maximumWidth: flick.width
                                implicitHeight: body.implicitHeight + Tokens.spacing.sm * 2
                                radius: Tokens.radius.medium
                                color: mine ? Chrome.tonal.bg : Colors.color.surfaceContainerHighest

                                MText {
                                    id: body
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Tokens.spacing.sm
                                    value: row.text || ""
                                    styleName: "bodyMedium"
                                    color: mine ? Chrome.tonal.fg : Colors.color.onSurface
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideNone
                                    lineHeightMode: Text.ProportionalHeight
                                }
                            }
                        }
                    }

                    MText {
                        visible: Ai.busy
                        key: "ai.thinking"
                        styleName: "bodySmall"
                        color: Colors.color.onSurfaceVariant
                    }
                }
            }

            MEmptyState {
                visible: root._off || Ai.history.length === 0
                anchors.fill: parent
                iconName: "mail-message-new-symbolic"
                titleKey: root._off ? "ai.disabled" : "ai.empty"
                hintKey: root._off ? "ai.enableHint" : "ai.hint"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs

            MTextField {
                id: field
                Layout.fillWidth: true
                enabled: !root._off && !Ai.busy
                placeholderKey: "ai.placeholder"
                onAccepted: root.send()
            }
            MIconButton {
                iconName: "document-send"
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
