import QtQuick
import "../../Commons"
import "../../Services"
import "actions.js" as ActionList

// What each command in actions.js does, and when it can. Menus and keys
// call run(id); they never reach into the panes themselves.
QtObject {
    id: root

    property var pane: null
    property var findBar: null
    property var flow: null
    property var goTo: null

    readonly property var _edit: root.pane ? root.pane.edit : null
    readonly property bool _writable: !EditorDoc.readOnly

    function def(id: string): var {
        return ActionList.byId(id);
    }

    function enabled(id: string): bool {
        const e = root._edit;
        const picked = !!e && e.selectionStart !== e.selectionEnd;
        switch (id) {
        case "save":
            return !EditorDoc.busy && (EditorDoc.dirty || !EditorDoc.path.length) && root._writable;
        case "saveAs":
        case "open":
        case "new":
            return !EditorDoc.busy;
        case "reveal":
            return EditorDoc.path.length > 0;
        case "trash":
            return !EditorDoc.busy && EditorDoc.path.length > 0 && EditorDoc.lock !== "claimed";
        case "undo":
            return !!e && e.canUndo && root._writable;
        case "redo":
            return !!e && e.canRedo && root._writable;
        case "cut":
        case "delete":
            return picked && root._writable;
        case "copy":
            return picked;
        case "paste":
            return !!e && e.canPaste && root._writable;
        case "findNext":
        case "findPrevious":
            return !!root.findBar && root.findBar.needle.length > 0;
        case "replace":
        case "timeDate":
            return root._writable;
        case "zoomIn":
            return EditorPrefs.zoom < EditorPrefs.zoomMax;
        case "zoomOut":
            return EditorPrefs.zoom > EditorPrefs.zoomMin;
        case "zoomReset":
            return EditorPrefs.zoom !== 100;
        default:
            if (id.indexOf("eol:") === 0)
                return root._writable;
            return true;
        }
    }

    function checked(id: string): bool {
        if (id === "wordWrap")
            return EditorPrefs.wordWrap;
        if (id === "monospace")
            return EditorPrefs.monospace;
        if (id === "statusBar")
            return EditorPrefs.statusBar;
        if (id.indexOf("eol:") === 0)
            return EditorDoc.eol === id.slice(4);
        return false;
    }

    function run(id: string) {
        if (!root.enabled(id))
            return;
        const e = root._edit;
        switch (id) {
        case "new": root.flow.newDocument(); break;
        case "newWindow": EditorDoc.openWindow(""); break;
        case "open": root.flow.chooseFile(); break;
        case "save": root.flow.save(null); break;
        case "saveAs": root.flow.saveAs(null); break;
        case "reveal": EditorDoc.reveal(); break;
        case "trash": root.flow.askTrash(); break;
        case "close": root.flow.close(); break;
        case "undo": e.undo(); break;
        case "redo": e.redo(); break;
        case "cut": e.cut(); break;
        case "copy": e.copy(); break;
        case "paste": e.paste(); break;
        case "delete": e.remove(e.selectionStart, e.selectionEnd); break;
        case "selectAll": e.selectAll(); break;
        case "find": root.findBar.show(false); break;
        case "replace": root.findBar.show(true); break;
        case "findNext": root.findBar.step(true); break;
        case "findPrevious": root.findBar.step(false); break;
        case "goTo": root.goTo.ask(); break;
        case "timeDate": root.pane.insertText(root._stamp()); break;
        case "wordWrap": EditorPrefs.setWordWrap(!EditorPrefs.wordWrap); break;
        case "monospace": EditorPrefs.setMonospace(!EditorPrefs.monospace); break;
        case "statusBar": EditorPrefs.setStatusBar(!EditorPrefs.statusBar); break;
        case "zoomIn": EditorPrefs.zoomBy(1); break;
        case "zoomOut": EditorPrefs.zoomBy(-1); break;
        case "zoomReset": EditorPrefs.setZoom(100); break;
        default:
            if (id.indexOf("eol:") === 0)
                EditorDoc.setEol(id.slice(4));
            break;
        }
        if (id !== "find" && id !== "replace" && id !== "goTo" && root.pane)
            root.pane.focusText();
    }

    function _stamp(): string {
        const now = new Date();
        return DateTime.formatTime(now, Config.language.timeFormat, false) + " "
            + DateTime.formatDate(now, Config.language.dateFormat);
    }

    // "Ctrl+Shift+S" in the words of the current language.
    function keyLabel(id: string): string {
        const a = ActionList.byId(id);
        if (!a || !a.keys.length)
            return "";
        const names = { Ctrl: "editor.keys.ctrl", Shift: "editor.keys.shift", Alt: "editor.keys.alt", Del: "editor.keys.delete" };
        return a.keys[0].split("+").map((part, i, all) => {
            if (part === "" && i === all.length - 1)
                return "+";
            return names[part] ? I18n.t(names[part]) : part;
        }).filter(p => p.length).join("+");
    }
}
