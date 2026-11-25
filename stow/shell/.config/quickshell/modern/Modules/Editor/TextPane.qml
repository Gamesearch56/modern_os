import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"
import "actions.js" as ActionList

// The page. Wrap, font, and zoom follow EditorPrefs. The text is only
// replaced when EditorDoc.serial moves (a load, New, or a restore after
// the window was closed with unsaved changes); typing never round-trips.
Item {
    id: root

    property var actions: null
    property alias edit: input
    property bool _loading: false
    readonly property int tabWidth: 4

    signal filesDropped(var urls)

    function focusText() {
        input.forceActiveFocus();
    }

    function insertText(text: string) {
        if (input.selectionStart !== input.selectionEnd)
            input.remove(input.selectionStart, input.selectionEnd);
        input.insert(input.cursorPosition, text);
    }

    function selectRange(start: int, end: int) {
        input.select(start, end);
        flick.ensureVisible(input.positionToRectangle(start));
    }

    function moveTo(pos: int) {
        input.deselect();
        input.cursorPosition = pos;
    }

    // Two undo steps instead of one per match, and the view stays put.
    function replaceText(text: string) {
        const keepY = flick.contentY;
        const at = input.cursorPosition;
        input.remove(0, input.length);
        input.insert(0, text);
        input.cursorPosition = Math.min(at, input.length);
        flick.contentY = Math.min(keepY, Math.max(0, flick.contentHeight - flick.height));
    }

    function _take() {
        root._loading = true;
        input.text = EditorDoc.text;
        root._loading = false;
        input.cursorPosition = 0;
        flick.contentX = 0;
        flick.contentY = 0;
    }

    Component.onCompleted: {
        if (EditorDoc.serial > 0)
            root._take();
    }

    Connections {
        target: EditorDoc
        function onSerialChanged() {
            root._take();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.medium
        color: Colors.color.surfaceContainerLow
        border.color: input.activeFocus ? Colors.color.outline : Colors.color.outlineVariant
        border.width: Tokens.stroke.hairline
    }

    FontMetrics {
        id: metrics
        font: input.font
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Tokens.spacing.md
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: input.width
        contentHeight: input.height

        function ensureVisible(r) {
            if (contentY > r.y)
                contentY = r.y;
            else if (contentY + height < r.y + r.height)
                contentY = r.y + r.height - height;
            if (contentX > r.x)
                contentX = r.x;
            else if (contentX + width < r.x + r.width)
                contentX = r.x + r.width - width;
        }

        TextEdit {
            id: input
            width: EditorPrefs.wordWrap ? flick.width : Math.max(flick.width, implicitWidth)
            height: Math.max(implicitHeight, flick.height)
            textFormat: TextEdit.PlainText
            wrapMode: EditorPrefs.wordWrap ? TextEdit.WrapAtWordBoundaryOrAnywhere : TextEdit.NoWrap
            font.family: EditorPrefs.monospace ? Typography.family.monospace : Typography.family.document
            font.pixelSize: Math.max(1, Math.round(Typography.style("bodyLarge").pixelSize * EditorPrefs.zoom / 100))
            tabStopDistance: metrics.advanceWidth(" ") * root.tabWidth
            color: Colors.color.onSurface
            selectionColor: Colors.color.primary
            selectedTextColor: Colors.color.onPrimary
            readOnly: EditorDoc.readOnly
            selectByMouse: true
            persistentSelection: true
            focus: true
            Accessible.role: Accessible.EditableText
            Accessible.name: EditorDoc.name
            Accessible.multiLine: true
            Accessible.readOnly: EditorDoc.readOnly
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            onTextChanged: {
                if (!root._loading)
                    EditorDoc.dirty = true;
            }
        }
    }

    MouseArea {
        anchors.fill: flick
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.IBeamCursor
        onPressed: (mouse) => {
            const p = mapToItem(input, mouse.x, mouse.y);
            const at = input.positionAt(p.x, p.y);
            if (at < input.selectionStart || at > input.selectionEnd || input.selectionStart === input.selectionEnd)
                root.moveTo(at);
            root.focusText();
            const w = mapToItem(null, mouse.x, mouse.y);
            context.openAt(w.x, w.y);
        }
    }

    WheelHandler {
        target: null
        acceptedModifiers: Qt.ControlModifier
        onWheel: (event) => {
            if (event.angleDelta.y !== 0)
                EditorPrefs.zoomBy(event.angleDelta.y > 0 ? 1 : -1);
        }
    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (drop) => {
            if (drop.hasUrls) {
                root.filesDropped(drop.urls.map(u => String(u)));
                drop.accept();
            }
        }
    }

    MActionMenu {
        id: context
        actions: root.actions
        items: ActionList.forContext()
    }
}
