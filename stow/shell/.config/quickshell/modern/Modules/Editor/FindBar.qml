import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"
import "textops.js" as TextOps

// Find and replace above the page, notepad style: Enter or F3 finds the
// next match, Shift+F3 the one before, Esc goes back to the text.
ColumnLayout {
    id: root

    property var pane: null
    property bool open: false
    property bool replacing: false
    property bool matchCase: false
    property bool wrap: true
    property bool missed: false
    property int hits: 0
    readonly property string needle: findField.text

    visible: root.open
    spacing: Tokens.spacing.sm

    function show(replace: bool) {
        const e = root.pane.edit;
        const picked = e.selectedText;
        if (picked.length > 0 && picked.indexOf("\n") < 0 && picked.indexOf("\u2029") < 0)
            findField.text = picked;
        root.replacing = replace && !EditorDoc.readOnly;
        root.open = true;
        Qt.callLater(() => {
            findField.forceActiveFocus();
            findField.editor.selectAll();
        });
    }

    function hide() {
        root.open = false;
        root.pane.focusText();
    }

    function step(forward: bool): bool {
        const e = root.pane.edit;
        const from = forward ? e.selectionEnd : e.selectionStart;
        const hit = TextOps.find(e.text, root.needle, from, forward, root.matchCase, root.wrap);
        root.missed = !hit && root.needle.length > 0;
        if (hit)
            root.pane.selectRange(hit.start, hit.end);
        return !!hit;
    }

    function _selectionIsMatch(): bool {
        const picked = root.pane.edit.selectedText;
        return root.matchCase ? picked === root.needle : picked.toLowerCase() === root.needle.toLowerCase();
    }

    function replaceOne() {
        if (root.needle.length === 0 || EditorDoc.readOnly)
            return;
        if (root._selectionIsMatch())
            root.pane.insertText(replaceField.text);
        root.step(true);
        recount.restart();
    }

    function replaceAll() {
        if (root.needle.length === 0 || EditorDoc.readOnly)
            return;
        const out = TextOps.replaceAll(root.pane.edit.text, root.needle, replaceField.text, root.matchCase);
        if (out.count > 0)
            root.pane.replaceText(out.text);
        root.missed = out.count === 0;
        recount.restart();
    }

    Timer {
        id: recount
        interval: Motion.shortMs
        onTriggered: root.hits = root.open ? TextOps.count(root.pane.edit.text, root.needle, root.matchCase) : 0
    }

    onNeedleChanged: {
        root.missed = false;
        recount.restart();
    }
    onMatchCaseChanged: recount.restart()
    onOpenChanged: recount.restart()

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MTextField {
            id: findField
            Layout.fillWidth: true
            iconName: "edit-find"
            placeholderKey: "editor.find.placeholder"
            onAccepted: root.step(true)
            onEscaped: root.hide()
        }
        MText {
            value: root.needle.length === 0 ? "" : (root.missed && root.hits === 0
                ? I18n.t("editor.find.none") : I18n.t("editor.find.count", { count: root.hits }))
            color: root.missed ? Colors.color.error : Colors.color.onSurfaceVariant
            styleName: "labelMedium"
            Accessible.role: Accessible.StaticText
        }
        MIconButton {
            iconName: "go-up"
            key: "editor.actions.findPrevious"
            tip: true
            enabled: root.needle.length > 0
            onClicked: root.step(false)
        }
        MIconButton {
            iconName: "go-down"
            key: "editor.actions.findNext"
            tip: true
            enabled: root.needle.length > 0
            onClicked: root.step(true)
        }
        MIconButton {
            iconName: "format-text-uppercase"
            key: "editor.find.matchCase"
            tip: true
            checked: root.matchCase
            onClicked: root.matchCase = !root.matchCase
        }
        MIconButton {
            iconName: "media-playlist-repeat"
            key: "editor.find.wrap"
            tip: true
            checked: root.wrap
            onClicked: root.wrap = !root.wrap
        }
        MIconButton {
            iconName: "edit-find-replace"
            key: "editor.actions.replace"
            tip: true
            checked: root.replacing
            enabled: !EditorDoc.readOnly
            onClicked: root.replacing = !root.replacing
        }
        MIconButton {
            close: true
            iconName: "window-close"
            key: "editor.find.close"
            tip: true
            onClicked: root.hide()
        }
    }

    RowLayout {
        visible: root.replacing
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        MTextField {
            id: replaceField
            Layout.fillWidth: true
            iconName: "edit-find-replace"
            placeholderKey: "editor.find.replacePlaceholder"
            onAccepted: root.replaceOne()
            onEscaped: root.hide()
        }
        MButton {
            kind: "tonal"
            key: "editor.find.replaceOne"
            enabled: root.needle.length > 0
            onClicked: root.replaceOne()
        }
        MButton {
            kind: "tonal"
            key: "editor.find.replaceAll"
            enabled: root.needle.length > 0
            onClicked: root.replaceAll()
        }
    }
}
