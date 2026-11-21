import QtQuick
import "../../Commons"
import "../../Services"

// The order of things: ask about unsaved changes before New, Open, or
// Close, fall back to Save As when there is no file to save into, and
// turn every refusal from EditorDoc into a dialog. The file manager's
// chooser is only touched once Open or Browse is used, so a plain edit
// never starts the Files service in this window.
Item {
    id: root

    property var module: null
    property var pane: null
    property var unsaved: null
    property var ask: null
    property var saveAsDialog: null

    property var _after: null
    property var _afterSave: null
    property var _target: null

    function _text(): string {
        return root.pane.edit.text;
    }

    function _run(next: var) {
        if (next)
            next();
    }

    function guard(next: var) {
        if (!EditorDoc.dirty) {
            root._run(next);
            return;
        }
        root._after = next;
        root.unsaved.open = true;
    }

    function newDocument() {
        root.guard(() => EditorDoc.reset());
    }

    function close() {
        root.guard(() => root.module.quit());
    }

    function chooseFile() {
        root.guard(() => {
            root.module.chooser = true;
            FilesChoose.ask(EditorDoc.folder.length ? EditorDoc.folder : XdgDirs.documents, "file", "editor-open");
        });
    }

    // The first dropped file opens here; the rest get their own windows.
    function openDropped(urls: var) {
        const list = (urls || []).map(u => String(u)).filter(u => u.length);
        if (!list.length)
            return;
        for (let i = 1; i < list.length; i++)
            EditorDoc.openWindow(list[i]);
        root.guard(() => EditorDoc.open(list[0]));
    }

    function save(next: var) {
        if (!EditorDoc.path.length || EditorDoc.readOnly) {
            root.saveAs(next);
            return;
        }
        EditorDoc.save(root._text(), (ok) => {
            if (ok)
                root._run(next);
            else
                root._afterSave = next;
        });
    }

    function saveAs(next: var) {
        root._afterSave = next;
        root.saveAsDialog.ask();
    }

    function askTrash() {
        root.ask.ask("trash", { name: EditorDoc.name });
    }

    function _saveAsTo(replace: bool) {
        const t = root._target;
        if (!t)
            return;
        EditorDoc.saveAs(t.path, root._text(), t.encoding, t.eol, replace, (ok) => {
            if (!ok)
                return;
            root._target = null;
            root.saveAsDialog.open = false;
            const next = root._afterSave;
            root._afterSave = null;
            root._run(next);
        });
    }

    Connections {
        target: root.unsaved
        function onSave() {
            const next = root._after;
            root._after = null;
            root.unsaved.open = false;
            root.save(next);
        }
        function onDiscard() {
            const next = root._after;
            root._after = null;
            root.unsaved.open = false;
            EditorDoc.dirty = false;
            root._run(next);
        }
    }

    Connections {
        target: root.saveAsDialog
        function onChosen(path, encoding, eol) {
            root._target = { path: path, encoding: encoding, eol: eol };
            root._saveAsTo(false);
        }
        function onBrowse(folder) {
            root.module.chooser = true;
            FilesChoose.ask(folder, "folder", "editor-folder");
        }
    }

    Connections {
        target: root.ask
        function onOpenChanged() {
            if (!root.ask.open && root.ask.kind === "notice")
                EditorDoc.clearNotice();
        }
        function onAgreed(kind) {
            if (kind === "exists")
                root._saveAsTo(true);
            else if (kind === "changed")
                EditorDoc.overwrite(root._text(), (ok) => {
                    if (ok) {
                        const next = root._afterSave;
                        root._afterSave = null;
                        root._run(next);
                    }
                });
            else if (kind === "trash")
                EditorDoc.trash((ok) => {
                    if (ok)
                        root.module.quit();
                });
        }
    }

    Connections {
        target: EditorDoc
        function onConflict() {
            root.ask.ask("changed", { name: EditorDoc.name });
        }
        function onExists(path) {
            root.ask.ask("exists", { name: path.slice(path.lastIndexOf("/") + 1) });
        }
        function onNoticeChanged() {
            if (EditorDoc.notice.length)
                root.ask.ask("notice", Object.assign({ key: EditorDoc.notice }, EditorDoc.noticeParams));
        }
    }

    Connections {
        target: root.module && root.module.chooser ? FilesChoose : null
        function onChosen(path, who) {
            if (who === "editor-open")
                EditorDoc.open(path);
            else if (who === "editor-folder")
                root.saveAsDialog.folder = path;
        }
    }
}
