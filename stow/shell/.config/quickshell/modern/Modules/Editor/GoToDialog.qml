import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "textops.js" as TextOps

// Jump to a line number, like Ctrl+G in a classic notepad.
MDialog {
    id: root

    property var pane: null
    property int _last: 1
    readonly property int _wanted: parseInt(field.text, 10)
    readonly property bool _valid: root._wanted >= 1 && root._wanted <= root._last

    function ask() {
        const e = root.pane.edit;
        root._last = TextOps.lineCount(e.text);
        field.text = String(TextOps.lineCol(e.text, e.cursorPosition).line);
        root.open = true;
        Qt.callLater(() => {
            field.forceActiveFocus();
            field.editor.selectAll();
        });
    }

    anchors.fill: parent
    titleKey: "editor.goTo.title"
    bodyKey: "editor.goTo.body"
    bodyParams: ({ last: root._last })
    confirmKey: "editor.goTo.go"
    cancelKey: "editor.cancel"
    confirmEnabled: root._valid
    onCancelled: {
        root.open = false;
        root.pane.focusText();
    }
    onConfirmed: {
        if (!root._valid)
            return;
        root.open = false;
        root.pane.moveTo(TextOps.lineStart(root.pane.edit.text, root._wanted));
        root.pane.focusText();
    }

    MTextField {
        id: field
        Layout.fillWidth: true
        iconName: "go-jump"
        placeholderKey: "editor.goTo.placeholder"
        maximumLength: 9
        editor.validator: IntValidator {
            bottom: 1
        }
        onAccepted: root.confirmed()
        onEscaped: root.cancelled()
    }
}
