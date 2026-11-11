// Multiline filled field. Window-rules editor and similar.
import QtQuick
import "../Commons"

Item {
    id: root

    property alias text: input.text
    property string placeholderKey: ""
    property bool expanded: false
    property bool _pointer: false

    readonly property bool _a11yFocus: input.activeFocus && !root._pointer

    signal textEdited()

    implicitHeight: root.expanded ? Tokens.spacing.xxl * 8 : Tokens.spacing.xxl * 4
    implicitWidth: Tokens.spacing.xxl * 12
    activeFocusOnTab: true

    HoverHandler {
        enabled: true
        cursorShape: Qt.IBeamCursor
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.surfaceContainerHighest
        border.color: root._a11yFocus ? Colors.color.primary : Colors.color.outline
        border.width: root._a11yFocus ? Tokens.stroke.focus : Tokens.stroke.hairline

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.shortMs
                easing.bezierCurve: Motion.easingStandard
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Tokens.spacing.sm
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        // The editor is at least the viewport tall, so a click in the
        // empty part of the box still lands in the text, not the scroller.
        contentHeight: input.height
        interactive: input.implicitHeight > height

        onMovementStarted: root._lockParent(true)
        onMovementEnded: root._lockParent(false)

        HoverHandler {
            onHoveredChanged: {
                if (hovered && flick.contentHeight > flick.height)
                    root._lockParent(true);
                else if (!hovered && !flick.moving)
                    root._lockParent(false);
            }
        }

        function ensureVisible(r) {
            if (contentY >= r.y)
                contentY = r.y;
            else if (contentY + height <= r.y + r.height)
                contentY = r.y + r.height - height;
        }

        TextEdit {
            id: input
            width: flick.width
            height: Math.max(implicitHeight, flick.height)
            wrapMode: TextEdit.Wrap
            color: Colors.color.onSurface
            selectionColor: Colors.color.primary
            selectedTextColor: Colors.color.onPrimary
            font.family: Typography.family.ui
            font.pixelSize: Typography.style("bodyMedium").pixelSize
            font.hintingPreference: Font.PreferNoHinting
            renderType: TextEdit.QtRendering
            selectByMouse: true
            activeFocusOnPress: true
            activeFocusOnTab: false
            onTextChanged: root.textEdited()
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    event.accepted = root._arrowMove(0, event.key === Qt.Key_Backtab ? -1 : 1);
                    return;
                }
                const editing = input.selectionStart !== input.selectionEnd;
                if (!editing && event.key === Qt.Key_Left && input.cursorPosition === 0) {
                    event.accepted = root._arrowMove(-1, 0);
                    return;
                }
                if (!editing && event.key === Qt.Key_Right && input.cursorPosition === input.length) {
                    event.accepted = root._arrowMove(1, 0);
                    return;
                }
                if (event.key === Qt.Key_Up && input.cursorRectangle.y <= 1) {
                    event.accepted = root._arrowMove(0, -1);
                    return;
                }
                if (event.key === Qt.Key_Down) {
                    const bottom = input.cursorRectangle.y + input.cursorRectangle.height;
                    const doc = Math.min(input.contentHeight, input.implicitHeight);
                    if (bottom >= doc - 1)
                        event.accepted = root._arrowMove(0, 1);
                }
            }
        }
    }

    MText {
        visible: input.text.length === 0 && !input.activeFocus
        enabled: false
        anchors.fill: flick
        key: root.placeholderKey
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        grabPermissions: PointerHandler.TakeOverForbidden
        onPressedChanged: {
            if (!pressed)
                return;
            root._pointer = true;
            const local = input.mapFromItem(root, point.position.x, point.position.y);
            input.forceActiveFocus();
            input.cursorPosition = input.positionAt(local.x, local.y);
        }
    }

    Connections {
        target: input
        function onActiveFocusChanged() {
            if (!input.activeFocus)
                root._pointer = false;
        }
    }

    onActiveFocusChanged: {
        if (root.activeFocus && !input.activeFocus)
            input.forceActiveFocus();
    }

    function _arrowMove(dx: int, dy: int): bool {
        let p = root.parent;
        while (p) {
            if (typeof p.arrowMove === "function")
                return p.arrowMove(dx, dy);
            p = p.parent;
        }
        return false;
    }

    function _lockParent(lock: bool) {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined) {
                p.interactive = !lock;
                return;
            }
            p = p.parent;
        }
    }
}
