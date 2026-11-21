pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// The one document of this Texteditor window. The live text belongs to
// the view; `text` here is only what a load or restore hands to it, and
// `serial` bumps when the view should take it. Every disk step goes
// through EditorIo. `lock` names why the file is read-only: "denied"
// (no write permission), "lossy" (characters a save would change), or
// "claimed" (another window has it open).
Singleton {
    id: root

    readonly property var _knownErrors: ["missing", "directory", "special", "tooLarge", "binary", "encoding",
        "denied", "readOnlyFs", "full", "badName", "changed", "exists", "unencodable", "protected", "busy"]

    property string path: ""
    property string encoding: "utf-8"
    property string eol: "lf"
    property bool standIn: false
    property string mtime: ""
    property bool dirty: false
    property string lock: ""
    property string text: ""
    property int serial: 0
    property string notice: ""
    property var noticeParams: ({})
    readonly property bool readOnly: root.lock.length > 0
    readonly property bool busy: EditorIo.busy
    readonly property string name: root.path.length ? root.path.slice(root.path.lastIndexOf("/") + 1) : I18n.t("editor.untitled")
    readonly property string folder: root.path.length ? (root.path.slice(0, root.path.lastIndexOf("/")) || "/") : ""

    signal opened()
    signal saved()
    signal conflict()
    signal exists(string path)
    signal trashed()

    function errorKey(reason: string): string {
        const r = String(reason || "");
        return "editor.errors." + (root._knownErrors.indexOf(r) >= 0 ? r : "failed");
    }

    function _say(out: var) {
        root.notice = root.errorKey(out.error);
        root.noticeParams = { name: root.name, megabytes: Math.ceil(Number(out.limit || 0) / 1048576) };
    }

    function clearNotice() {
        root.notice = "";
        root.noticeParams = ({});
    }

    function _show(text: string) {
        root.text = text;
        root.dirty = false;
        root.serial++;
    }

    // Text from a window the compositor closed with unsaved changes, for
    // the window that replaces it. It stays unsaved.
    function restore(text: string) {
        root.text = text;
        root.dirty = true;
        root.serial++;
    }

    // Hands the file back so the next window opening it is not read-only.
    function leave() {
        root._release();
    }

    function _release() {
        if (root.path.length)
            EditorIo.run(["release", root.path, String(Quickshell.processId)], null, null);
    }

    function _claim() {
        const wanted = root.path;
        EditorIo.run(["claim", wanted, String(Quickshell.processId)], null, (out) => {
            if (root.path === wanted && !out.ok && out.error === "open" && root.lock.length === 0)
                root.lock = "claimed";
        });
    }

    function reset() {
        root._release();
        root.path = "";
        root.encoding = "utf-8";
        root.eol = "lf";
        root.standIn = false;
        root.mtime = "";
        root.lock = "";
        root.clearNotice();
        root._show("");
    }

    function open(raw: string) {
        const wanted = String(raw || "").trim();
        if (!wanted.length)
            return;
        const limit = Math.max(1, Number(Config.editor.maxMegabytes || 8)) * 1048576;
        EditorIo.run(["load", wanted, "--max-bytes", String(limit)], null, (out) => {
            if (!out.ok) {
                if (out.error === "missing" && !root.path.length) {
                    // A new name from the file manager or a terminal: start it empty.
                    root.reset();
                    root.path = wanted;
                    root._claim();
                    root.opened();
                    return;
                }
                root._say(out);
                return;
            }
            root._release();
            root.path = String(out.path || wanted);
            root.encoding = String(out.encoding || "utf-8");
            root.eol = String(out.eol || "lf");
            root.standIn = out.standIn === true;
            root.mtime = String(out.mtime || "");
            root.lock = out.lossy ? "lossy" : (out.writable === false ? "denied" : "");
            root.clearNotice();
            root._show(String(out.text || ""));
            root._claim();
            root.opened();
        });
    }

    // done(true) after a save, done(false) when it did not happen.
    function save(text: string, done: var) {
        root._write(root.path, text, root.encoding, root.eol, root.mtime.length ? ["--expect", root.mtime] : [], done);
    }

    function overwrite(text: string, done: var) {
        root._write(root.path, text, root.encoding, root.eol, [], done);
    }

    function saveAs(target: string, text: string, encoding: string, eol: string, replace: bool, done: var) {
        root._write(target, text, encoding, eol, replace ? [] : ["--no-clobber"], done);
    }

    function _write(target: string, text: string, encoding: string, eol: string, extra: var, done: var) {
        const finish = (ok) => {
            if (done)
                done(ok);
        };
        if (!target.length || (target === root.path && root.lock.length > 0)) {
            finish(false);
            return;
        }
        const sameFile = target === root.path;
        const args = ["save", target, "--encoding", encoding, "--eol", eol];
        if (sameFile && root.standIn)
            args.push("--stand-in");
        EditorIo.run(args.concat(extra), text, (out) => {
            if (!out.ok) {
                if (out.error === "changed")
                    root.conflict();
                else if (out.error === "exists")
                    root.exists(target);
                else
                    root._say(out);
                finish(false);
                return;
            }
            if (!sameFile) {
                root._release();
                root.path = String(out.path || target);
                root.standIn = false;
                root._claim();
            }
            root.encoding = encoding;
            root.eol = eol;
            root.mtime = String(out.mtime || "");
            root.dirty = false;
            root.clearNotice();
            root.saved();
            finish(true);
        });
    }

    function trash(done: var) {
        if (!root.path.length || root.lock === "claimed") {
            if (done)
                done(false);
            return;
        }
        EditorIo.run(["trash", root.path], null, (out) => {
            if (!out.ok) {
                root._say(out);
                if (done)
                    done(false);
                return;
            }
            root._release();
            root.path = "";
            root.mtime = "";
            root.lock = "";
            root.dirty = false;
            root.trashed();
            if (done)
                done(true);
        });
    }

    // Another window, empty or for one file. A file open elsewhere gets
    // that window focused instead (scripts/modern-editor).
    function openWindow(target: string) {
        const args = [Paths.script("modern-editor")];
        if (String(target || "").length)
            args.push(String(target));
        Quickshell.execDetached(args);
    }

    function reveal() {
        if (root.path.length)
            Quickshell.execDetached(["qs", "-c", "modern", "ipc", "call", "files", "reveal", root.path]);
    }

    function setEol(value: string) {
        if (value !== root.eol && !root.readOnly) {
            root.eol = value;
            root.dirty = true;
        }
    }
}
