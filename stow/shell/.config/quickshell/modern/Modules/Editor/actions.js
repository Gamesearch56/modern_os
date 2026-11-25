.pragma library
// Every Texteditor command, once. The menus, the keyboard, and the
// right-click menu all read this list, so a new command is one row here
// plus its case in Actions.qml. `native` keys are already handled by the
// text field itself; they are shown in the menu but not bound again.

var list = [
    { id: "new", key: "editor.actions.new", icon: "document-new", keys: ["Ctrl+N"], menu: "file" },
    { id: "newWindow", key: "editor.actions.newWindow", icon: "window-new", keys: ["Ctrl+Shift+N"], menu: "file" },
    { id: "open", key: "editor.actions.open", icon: "document-open", keys: ["Ctrl+O"], menu: "file" },
    { id: "save", key: "editor.actions.save", icon: "document-save", keys: ["Ctrl+S"], menu: "file" },
    { id: "saveAs", key: "editor.actions.saveAs", icon: "document-save-as", keys: ["Ctrl+Shift+S"], menu: "file" },
    { id: "reveal", key: "editor.actions.reveal", icon: "folder-open", keys: [], menu: "file" },
    { id: "trash", key: "editor.actions.trash", icon: "user-trash", keys: [], menu: "file", danger: true },
    { id: "close", key: "editor.actions.close", icon: "window-close", keys: ["Ctrl+W"], menu: "file" },

    { id: "undo", key: "editor.actions.undo", icon: "edit-undo", keys: ["Ctrl+Z"], native: true, menu: "edit", context: true },
    { id: "redo", key: "editor.actions.redo", icon: "edit-redo", keys: ["Ctrl+Y", "Ctrl+Shift+Z"], native: true, menu: "edit", context: true },
    { id: "cut", key: "editor.actions.cut", icon: "edit-cut", keys: ["Ctrl+X"], native: true, menu: "edit", context: true, divider: true },
    { id: "copy", key: "editor.actions.copy", icon: "edit-copy", keys: ["Ctrl+C"], native: true, menu: "edit", context: true },
    { id: "paste", key: "editor.actions.paste", icon: "edit-paste", keys: ["Ctrl+V"], native: true, menu: "edit", context: true },
    { id: "delete", key: "editor.actions.delete", icon: "edit-delete", keys: ["Del"], native: true, menu: "edit", context: true },
    { id: "find", key: "editor.actions.find", icon: "edit-find", keys: ["Ctrl+F"], menu: "edit", divider: true },
    { id: "findNext", key: "editor.actions.findNext", icon: "go-down", keys: ["F3"], menu: "edit" },
    { id: "findPrevious", key: "editor.actions.findPrevious", icon: "go-up", keys: ["Shift+F3"], menu: "edit" },
    { id: "replace", key: "editor.actions.replace", icon: "edit-find-replace", keys: ["Ctrl+H"], menu: "edit" },
    { id: "goTo", key: "editor.actions.goTo", icon: "go-jump", keys: ["Ctrl+G"], menu: "edit" },
    { id: "selectAll", key: "editor.actions.selectAll", icon: "edit-select-all", keys: ["Ctrl+A"], native: true, menu: "edit", context: true, divider: true },
    { id: "timeDate", key: "editor.actions.timeDate", icon: "view-calendar-day", keys: ["F5"], menu: "edit" },

    { id: "wordWrap", key: "editor.actions.wordWrap", icon: "text-wrap", keys: ["Alt+Z"], menu: "view", toggle: true },
    { id: "monospace", key: "editor.actions.monospace", icon: "format-text-code", keys: [], menu: "view", toggle: true },
    { id: "statusBar", key: "editor.actions.statusBar", icon: "view-list-details", keys: [], menu: "view", toggle: true },
    { id: "zoomIn", key: "editor.actions.zoomIn", icon: "zoom-in", keys: ["Ctrl++", "Ctrl+="], menu: "view", divider: true },
    { id: "zoomOut", key: "editor.actions.zoomOut", icon: "zoom-out", keys: ["Ctrl+-"], menu: "view" },
    { id: "zoomReset", key: "editor.actions.zoomReset", icon: "zoom-original", keys: ["Ctrl+0"], menu: "view" },

    { id: "eol:lf", key: "editor.eol.lf", icon: "", keys: [], menu: "eol", toggle: true },
    { id: "eol:crlf", key: "editor.eol.crlf", icon: "", keys: [], menu: "eol", toggle: true },
    { id: "eol:cr", key: "editor.eol.cr", icon: "", keys: [], menu: "eol", toggle: true }
];

function byId(id) {
    for (let i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i];
    }
    return null;
}

function inMenu(menu) {
    return list.filter(a => a.menu === menu);
}

function forContext() {
    return list.filter(a => a.context === true);
}

function bindable() {
    return list.filter(a => !a.native && a.keys.length > 0);
}
