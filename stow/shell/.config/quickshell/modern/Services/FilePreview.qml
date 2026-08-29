// Spacebar Quick Look. Owns mime sniffing, text reads, and the mpv
// process for video. Modules/FilePreview never touches disk.
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
    property string fileName: ""
    property bool imageFailed: false
    property int _openToken: 0
    property int _mimeToken: 0
    property string _videoPath: ""

    readonly property bool showOverlay: root.open && (root.kind === "image" || root.kind === "text")
    readonly property string home: Quickshell.env("HOME")
    readonly property string mpvInput: root.home + "/modern_dotfile/scripts/lib/quicklook-mpv-input.conf"

    signal previewFailed(string key, string name)

    FileView {
        id: textFile
        path: root.kind === "text" && root.path.length > 0 ? root.path : ""
        printErrors: false
        onLoaded: {
            const t = text();
            root.textContent = t.length > 65536 ? t.slice(0, 65536) + "\n…" : t;
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
        id: videoProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: {
            if (root._videoPath.length > 0 && root.path === root._videoPath)
                root.hide();
        }
    }

    function toggle() {
        if (root.open)
            root.hide();
    }

    function hide() {
        root._openToken += 1;
        mimeProc.running = false;
        root._videoPath = "";
        videoProc.running = false;
        root.open = false;
        root.kind = "";
        root.mime = "";
        root.path = "";
        root.fileName = "";
        root.textContent = "";
        root.imageFailed = false;
    }

    function openPath(raw: string) {
        const p = root._normalize(raw);
        if (!p) {
            root._fail("filePreview.noSelection");
            return;
        }
        root.hide();
        root._openToken += 1;
        root._mimeToken = root._openToken;
        root.path = p;
        root.fileName = p.split("/").pop();
        mimeProc.command = ["file", "--brief", "--mime-type", "--", p];
        mimeProc.running = true;
    }

    function markImageFailed() {
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
        if (k === "other") {
            root._fail("filePreview.unsupported");
            return;
        }
        root.kind = k;
        if (k === "video") {
            root.open = true;
            root._videoPath = root.path;
            videoProc.command = [
                "mpv",
                "--force-window=immediate",
                "--wayland-app-id=modern.quicklook",
                "--x11-name=modern.quicklook",
                "--title=modern.quicklook",
                "--no-terminal",
                "--keep-open=yes",
                "--autofit=80%x80%",
                "--input-conf=" + root.mpvInput,
                root.path
            ];
            videoProc.running = true;
            return;
        }
        root.open = true;
        if (k === "text")
            textFile.reload();
    }

    function _kindFrom(mime: string, path: string): string {
        const ext = path.split(".").pop().toLowerCase();
        if (mime === "inode/directory")
            return "other";
        const images = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "jxl", "ico"];
        const videos = ["mp4", "mkv", "webm", "avi", "mov", "m4v", "ogv"];
        const texts = ["txt", "md", "json", "xml", "csv", "html", "css", "js", "ts", "qml", "conf", "log", "ini", "yaml", "yml", "toml", "rst"];
        if (mime.indexOf("image/") === 0 || images.indexOf(ext) >= 0)
            return "image";
        if (mime.indexOf("video/") === 0 || videos.indexOf(ext) >= 0)
            return "video";
        if (mime.indexOf("text/") === 0 || mime === "application/json" || mime === "application/xml"
                || mime === "application/javascript" || mime === "inode/x-empty" || texts.indexOf(ext) >= 0)
            return "text";
        return "other";
    }
}
