// Multiline filled field. Window-rules editor and similar.
import QtQuick
import "../Commons"

Item {
    id: root

    property alias text: input.text
    property string placeholderKey: ""
    property bool expanded: false

    signal textEdited()

    implicitHeight: root.expanded ? Tokens.spacing.xxl * 8 : Tokens.spacing.xxl * 4
    implicitWidth: Tokens.spacing.xxl * 12

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.surfaceContainerHighest
        border.color: input.activeFocus ? Colors.color.primary : Colors.color.outline
        border.width: input.activeFocus ? 2 : 1

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
        contentHeight: Math.max(height, input.implicitHeight)
        interactive: contentHeight > height

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
            wrapMode: TextEdit.Wrap
            color: Colors.color.onSurface
            selectionColor: Colors.color.primary
            selectedTextColor: Colors.color.onPrimary
            font.family: Typography.family.ui
            font.pixelSize: Typography.style("bodyMedium").pixelSize
            font.hintingPreference: Font.PreferNoHinting
            renderType: TextEdit.QtRendering
            selectByMouse: true
            onTextChanged: root.textEdited()
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down)
                    event.accepted = false;
            }
        }
    }

    MText {
        visible: input.text.length === 0 && !input.activeFocus
        anchors.fill: flick
        key: root.placeholderKey
        styleName: "bodyMedium"
        color: Colors.color.onSurfaceVariant
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
