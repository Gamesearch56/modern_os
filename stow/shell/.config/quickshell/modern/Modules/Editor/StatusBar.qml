import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"
import "actions.js" as ActionList
import "textops.js" as TextOps

// Line and column, length, zoom, line endings, and encoding. Line math
// waits for a pause in typing so a long file stays responsive.
RowLayout {
    id: root

    property var pane: null
    property var actions: null
    property int line: 1
    property int column: 1

    spacing: Tokens.spacing.lg

    Timer {
        id: settle
        interval: Motion.shortMs
        onTriggered: {
            const e = root.pane.edit;
            const at = TextOps.lineCol(e.text, e.cursorPosition);
            root.line = at.line;
            root.column = at.column;
        }
    }

    Connections {
        target: root.pane ? root.pane.edit : null
        function onCursorPositionChanged() {
            settle.restart();
        }
    }

    MTag {
        visible: EditorDoc.readOnly
        tone: "muted"
        key: "editor.readOnly." + (EditorDoc.lock.length ? EditorDoc.lock : "denied")
    }

    MText {
        value: I18n.t("editor.status.position", { line: root.line, column: root.column })
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
    }

    MText {
        value: I18n.t("editor.status.characters", { count: root.pane ? root.pane.edit.length : 0 })
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
    }

    Item {
        Layout.fillWidth: true
    }

    MText {
        value: I18n.t("editor.status.zoom", { percent: EditorPrefs.zoom })
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
    }

    MButton {
        id: eolButton
        kind: "text"
        key: "editor.eol." + EditorDoc.eol
        enabled: !EditorDoc.readOnly
        onClicked: eolMenu.open = !eolMenu.open
        Accessible.description: I18n.t("editor.status.lineEnding")

        MActionMenu {
            id: eolMenu
            actions: root.actions
            items: ActionList.inMenu("eol")
        }
    }

    MText {
        value: I18n.t("editor.encoding." + EditorDoc.encoding.replace(/-/g, ""))
        styleName: "labelMedium"
        color: Colors.color.onSurfaceVariant
        Accessible.description: I18n.t("editor.status.encoding")
    }
}
