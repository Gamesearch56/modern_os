// Spacebar Quick Look. Owns mime sniffing, text reads, folder lists and
// thumbnails. Modules/FilePreview never touches disk; its video window
// only hands `path` to Qt Multimedia.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool open: false
    property string path: ""
    property string kind: ""
    property string mime: ""
    property string textContent: ""
    property string listing: ""
    property var rows: []
    property string imagePath: ""
    property string fileName: ""
    property bool imageFailed: false
    property int _openToken: 0
    property int _mimeToken: 0
    property int _folderToken: 0
    property bool _spaceNoted: false
    property bool _spaceArmed: false
    property bool _fellBack: false

    readonly property bool showOverlay: root.open && (root.kind === "text" || root.kind === "folder" || root.kind === "file")
    readonly property string home: Quickshell.env("HOME")

    signal previewFailed(string key, string name)

    // Space is non-consuming, and a slow machine maps the preview after
    // that press is still in flight. Stay closed to Space until then.
    Timer {
        id: spaceArm
        interval: Motion.extraLongMs
        onTriggered: root._spaceArmed = true
    }

    FileView {
        id: textFile
        path: root.kind === "text" && root.path.length > 0 ? root.path : ""
        printErrors: false
        onLoaded: {
            const t = text();
            root.textContent = t.trim().length ? (t.length > 65536 ? t.slice(0, 65536) + "\n…" : t) : I18n.t("filePreview.emptyFile");
        }
        onLoadFailed: {
            if (root.kind !== "text" || root.path.length === 0)
                return;
            root.textContent = "";
            root._fail("filePreview.loadFailed");
        }
    }

    Process {
        id: mimeProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._mimeToken !== root._openToken)
                    return;
                root._onMime(this.text);
            }
        }
        stderr: StdioCollector {}
        onExited: (code) => {
            if (root._mimeToken !== root._openToken)
                return;
            if (code !== 0 && root.path.length > 0 && root.kind.length === 0)
                root._fail("filePreview.unsupported");
        }
    }

    Process {
        id: folderProc
        running: false
        stdout: StdioCollector { onStreamFinished: root._onFolder(this.text) }
        onExited: (code) => {
            if (code !== 0 && root._folderToken === root._openToken && root.kind === "folder" && !root.listing.length && !(root.rows || []).length) {
                root.rows = [];
                root.listing = I18n.t("files.noAccess");
            }
        }
    }

    Process {
        id: thumbProc
        running: false
        stdout: SplitParser { onRead: (line) => root._onThumb(line) }
        onExited: {
            if (root.kind === "image" && root._fellBack && root.imagePath === root.path)
                root._fail("filePreview.loadFailed");
            else if (root.kind === "page" && !root.imagePath.length && root.open)
                root._fail("filePreview.loadFailed");
        }
    }

    function toggle() { if (root.open) root.hide(); }
    function noteSpace() { root._spaceNoted = true; Qt.callLater(() => root._spaceNoted = false); }
    function spaceHide() {
        if (!root.open || !root._spaceArmed)
            return;
        root.noteSpace();
        root.hide();
    }
    function spaceReady(): bool { return root.open && root._spaceArmed; }

    function togglePath(path: string) {
        if (root._spaceNoted || root.open) {
            root._spaceNoted = false;
            root.spaceHide();
            return;
        }
        if (!path.length) { root._fail("filePreview.noSelection"); return; }
        root.openPath(path);
    }

    function hide() {
        spaceArm.stop();
        root._spaceArmed = false;
        root._openToken += 1;
        mimeProc.running = false; folderProc.running = false; thumbProc.running = false;
        root.open = false; root.kind = ""; root.mime = ""; root.path = ""; root.fileName = "";
        root.textContent = ""; root.listing = ""; root.rows = []; root.imagePath = ""; root.imageFailed = false;
    }

    function openPath(raw: string) {
        const p = root._normalize(raw);
        if (!p) {
            if (!root.open) root._fail("filePreview.noSelection");
            return;
        }
        root._openToken += 1;
        mimeProc.running = false; folderProc.running = false; thumbProc.running = false;
        root.kind = ""; root.mime = ""; root.textContent = ""; root.listing = ""; root.rows = [];
        root.imagePath = ""; root.imageFailed = false; root._fellBack = false;
        root.path = p; root.fileName = p.split("/").pop();
        root._spaceArmed = false; spaceArm.restart();
        root.open = true;
        root._mimeToken = root._openToken;
        mimeProc.command = ["file", "--brief", "--mime-type", "--", p];
        mimeProc.running = true;
    }

    // The previewed file in its default app, as Enter in Files opens it.
    function openFull() {
        if (!root.path.length)
            return;
        Quickshell.execDetached([Paths.script("files-open.sh"), root.path]);
        root.hide();
    }

    function markVideoFailed() {
        if (root.kind === "video")
            root._fail("filePreview.loadFailed");
    }

    function markImageFailed() {
        if (root.kind === "image" && !root._fellBack) {
            root._fellBack = true;
            root._thumb();
            return;
        }
        if (thumbProc.running)
            return;
        root.imageFailed = true;
        root._fail("filePreview.loadFailed");
    }

    function _fail(key: string) {
        const name = root.fileName;
        root.hide();
        root.previewFailed(key, name);
    }

    function _normalize(raw: string): string {
        let p = (raw || "").trim().split("\n")[0].trim();
        if (p.startsWith("file:")) {
            p = decodeURIComponent(p.replace(/^file:\/\//, ""));
            if (!p.startsWith("/"))
                p = "/" + p;
        }
        return p;
    }

    function _onMime(out: string) {
        if (root._mimeToken !== root._openToken || !root.path.length)
            return;
        root.mime = (out || "").trim().split("\n")[0].trim().toLowerCase();
        const k = root._kindFrom(root.mime, root.path);
        root.kind = k;
        if (k === "folder") {
            root.open = true;
            root._listFolder();
            return;
        }
        if (k === "file" || k === "page") { root.open = true; root._thumb(); return; }
        root.open = true;
        if (k === "image")
            root.imagePath = root.path;
        if (k === "text")
            textFile.reload();
    }

    function _listFolder() {
        root._folderToken = root._openToken;
        root.listing = ""; root.rows = [];
        const hidden = Config.files.showHidden === true ? "1" : "0";
        folderProc.command = [Paths.script("files-ops.sh"), "list", root.path, hidden, "name", "0", "1"];
        folderProc.running = true;
    }

    function _onFolder(out: string) {
        if (root._folderToken !== root._openToken || root.kind !== "folder")
            return;
        let rows = [];
        try { rows = JSON.parse(out || "[]"); } catch (e) { rows = []; }
        if (!Array.isArray(rows))
            return;
        const shown = [];
        for (let i = 0; i < rows.length && shown.length < 100; i++)
            shown.push({ name: String(rows[i].name || ""), dir: rows[i].dir === true });
        if (rows.length > 100)
            shown.push({ name: "…", dir: false, more: true });
        root.rows = shown;
        root.listing = shown.length ? "" : I18n.t("filePreview.emptyFolder");
    }

    function _thumb() {
        thumbProc.command = [Paths.script("files-thumbs.sh"), "--edge", "1600", root.path];
        thumbProc.running = true;
    }

    function _onThumb(line: string) {
        if (!root.open || (root.kind !== "file" && root.kind !== "page" && !(root.kind === "image" && root._fellBack)))
            return;
        const text = String(line || "");
        const at = text.indexOf("\t");
        if (at <= 0)
            return;
        const dest = text.slice(at + 1);
        if (dest.length)
            root.imagePath = dest;
    }

    function _kindFrom(mime: string, path: string): string {
        if (mime === "inode/directory")
            return "folder";
        if (mime === "inode/x-empty" || mime === "application/x-empty") return "text";
        const ext = path.split(".").pop().toLowerCase();
        const images = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "jxl", "ico"];
        const videos = ["mp4", "mkv", "webm", "avi", "mov", "m4v", "ogv"];
        const texts = ["txt", "md", "json", "xml", "csv", "html", "css", "js", "ts", "qml", "conf", "log", "ini", "yaml", "yml", "toml", "rst"];
        if (mime.indexOf("image/") === 0 || images.indexOf(ext) >= 0)
            return "image";
        if (mime === "application/pdf" || mime === "application/postscript" || ext === "pdf" || ext === "ps" || ext === "eps")
            return "page";
        if (mime.indexOf("video/") === 0 || videos.indexOf(ext) >= 0)
            return "video";
        if (mime.indexOf("text/") === 0 || mime === "application/json" || mime === "application/xml"
                || mime === "application/javascript" || texts.indexOf(ext) >= 0)
            return "text";
        return "file";
    }
}
