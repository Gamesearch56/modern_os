// One chat turn. Mine (user) hugs the right; assistant hugs the left.
// Waiting is typing dots in this bubble, not a second card or a status line.
import QtQuick
import QtQuick.Layouts
import "../Commons"

Item {
    id: root

    property bool mine: false
    property string text: ""
    property string thinking: ""
    property string phase: ""
    property bool pending: false

    readonly property bool _table: !root.mine && md.hasTable(root.text)
    readonly property real _max: {
        if (!root._table)
            return Math.min(width * 0.82, Tokens.spacing.xxl * 12);
        return Math.max(1, width - Tokens.icon.md - Tokens.spacing.sm);
    }
    readonly property real _pad: Tokens.spacing.sm * 2
    readonly property real _inner: Math.max(1, root._max - root._pad)
    readonly property var _bodyStyle: {
        void Typography.scale;
        return Typography.style("bodyMedium");
    }
    readonly property real _bodyW: Math.min(root._inner, Math.max(1, body.implicitWidth))
    readonly property bool _wait: !root.mine && root.pending && root.text.length === 0
    readonly property bool _search: root._wait && root.phase === "search"
    readonly property bool _reason: !root.mine && String(root.thinking || "").trim().length > 0
    readonly property real _colW: {
        if (root._search)
            return root._max;
        if (root._wait)
            return dots.implicitWidth + root._pad;
        if (!root.mine)
            return root._max;
        return Math.min(root._max, root._bodyW + root._pad);
    }

    MMarkdown { id: md }

    implicitHeight: col.implicitHeight
    implicitWidth: width

    MIcon {
        id: glyph
        visible: !root.mine
        anchors.left: parent.left
        anchors.top: parent.top
        name: "applications-science-symbolic"
        size: Tokens.icon.md
        color: Colors.color.primary
        tint: true
        opacity: root._wait ? glyphPulse.opacity : 1

        SequentialAnimation {
            id: glyphPulse
            property real opacity: 1
            running: root._wait
            loops: Animation.Infinite
            NumberAnimation {
                target: glyphPulse
                property: "opacity"
                from: Tokens.overlay.lock
                to: 1
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingStandard
            }
            NumberAnimation {
                target: glyphPulse
                property: "opacity"
                from: 1
                to: Tokens.overlay.lock
                duration: Motion.mediumMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.top: parent.top
        anchors.left: root.mine ? undefined : glyph.right
        anchors.right: root.mine ? parent.right : undefined
        anchors.leftMargin: root.mine ? 0 : Tokens.spacing.sm
        width: root._colW
        spacing: Tokens.spacing.xxs

        Rectangle {
            visible: root.text.length > 0 || root._wait || root._reason
            Layout.fillWidth: true
            clip: true
            implicitHeight: inner.implicitHeight + root._pad
            radius: Tokens.radius.medium
            color: root.mine ? Chrome.tonal.bg : Colors.color.surfaceContainerHighest

            ColumnLayout {
                id: inner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.spacing.sm
                spacing: Tokens.spacing.xs

                MText {
                    visible: root._reason
                    key: "ai.reasoning"
                    styleName: "labelSmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MText {
                    visible: root._reason
                    value: root.thinking
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    markdown: true
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    Layout.fillWidth: true
                }
                MTypingDots {
                    id: dots
                    visible: root._wait
                    running: root._wait
                }
                MText {
                    visible: root._search
                    key: "ai.searching"
                    styleName: "labelMedium"
                    color: Colors.color.onSurfaceVariant
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                TextEdit {
                    id: body
                    visible: root.mine && root.text.length > 0
                    readOnly: true
                    selectByMouse: false
                    cursorVisible: false
                    persistentSelection: true
                    text: root.text
                    textFormat: TextEdit.PlainText
                    color: Chrome.tonal.fg
                    selectionColor: Colors.color.primary
                    selectedTextColor: Colors.color.onPrimary
                    wrapMode: TextEdit.Wrap
                    font.family: Typography.family.ui
                    font.pixelSize: root._bodyStyle.pixelSize
                    font.weight: root._bodyStyle.weight
                    font.letterSpacing: root._bodyStyle.letterSpacing
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: TextEdit.QtRendering
                    Layout.maximumWidth: root._inner

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        preventStealing: true
                        property int _anchor: 0
                        onPressed: (mouse) => {
                            body.forceActiveFocus();
                            _anchor = body.positionAt(mouse.x, mouse.y);
                            body.cursorPosition = _anchor;
                            body.deselect();
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed)
                                body.select(_anchor, body.positionAt(mouse.x, mouse.y));
                        }
                        onDoubleClicked: body.selectWord()
                    }
                }
                Repeater {
                    model: !root.mine && root.text.length > 0 ? md.blocks(root.text) : []
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.bottomMargin: modelData.kind === "table" ? Tokens.spacing.md : 0
                        spacing: Tokens.spacing.xs

                        TextEdit {
                            visible: modelData.kind !== "table"
                            readOnly: true
                            selectByMouse: false
                            cursorVisible: false
                            persistentSelection: true
                            text: modelData.html || ""
                            textFormat: TextEdit.RichText
                            color: Colors.color.onSurface
                            selectionColor: Colors.color.primary
                            selectedTextColor: Colors.color.onPrimary
                            wrapMode: TextEdit.Wrap
                            font.family: Typography.family.ui
                            font.pixelSize: root._bodyStyle.pixelSize
                            font.weight: root._bodyStyle.weight
                            font.letterSpacing: root._bodyStyle.letterSpacing
                            font.hintingPreference: Font.PreferNoHinting
                            renderType: TextEdit.QtRendering
                            Layout.fillWidth: true

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.ArrowCursor
                                preventStealing: true
                                property int _anchor: 0
                                onPressed: (mouse) => {
                                    parent.forceActiveFocus();
                                    _anchor = parent.positionAt(mouse.x, mouse.y);
                                    parent.cursorPosition = _anchor;
                                    parent.deselect();
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed)
                                        parent.select(_anchor, parent.positionAt(mouse.x, mouse.y));
                                }
                                onDoubleClicked: parent.selectWord()
                            }
                        }
                        MChatTable {
                            visible: modelData.kind === "table"
                            rows: modelData.rows || []
                            align: modelData.align || []
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
