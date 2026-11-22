// Image, video, and PDF previews for the file manager. Owns the
// thumbnail process and the path-to-file map. Modules only read source().
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property var map: ({})
    property int rev: 0
    property var _rows: []
    property var _wanted: ({})
    property var _queue: []
    property string _key: ""
    property var _buf: ({})

    readonly property string _images: "|jpg|jpeg|jpe|png|gif|webp|bmp|tif|tiff|avif|heic|heif|jxl|svg|ico|"
    readonly property string _videos: "|mp4|m4v|mkv|webm|mov|avi|mpg|mpeg|wmv|flv|ogv|3gp|m2ts|ts|"
    readonly property string _files: "|pdf|"

    function source(path: string): string {
        void root.rev;
        const hit = root.map[String(path || "")];
        if (typeof hit === "string" && hit.length > 0)
            return "file://" + hit;
        return "";
    }

    function glyph(entry: var): string {
        if (!entry || entry.dir)
            return "folder";
        const ext = root._ext(entry);
        const named = root._named(ext);
        if (named.length)
            return named;
        if (root._has(root._images, ext))
            return "image-x-generic";
        if (root._has(root._videos, ext))
            return "video-x-generic";
        if (root._has(root._files, ext))
            return "application-pdf";
        return "text-x-generic";
    }

    function _named(ext: var): string {
        const rows = [
            ["|exe|msi|bat|cmd|com|appimage|", "application-x-executable"],
            ["|dll|so|dylib|", "application-x-sharedlib"],
            ["|zip|7z|rar|tar|gz|tgz|bz2|xz|zst|", "package-x-generic"],
            ["|deb|rpm|pkg|", "package-x-generic"],
            ["|py|sh|js|ts|jsx|tsx|rb|pl|lua|", "text-x-script"],
            ["|html|htm|css|", "text-html"],
            ["|mp3|flac|ogg|wav|aac|m4a|opus|", "audio-x-generic"],
            ["|iso|img|", "application-x-cd-image"],
            ["|o|obj|a|lib|", "application-x-object"]
        ];
        for (let i = 0; i < rows.length; i++) {
            if (root._has(rows[i][0], ext))
                return rows[i][1];
        }
        return "";
    }

    function video(entry: var): bool {
        return !!(entry && !entry.dir && root._has(root._videos, root._ext(entry)));
    }

    function watch(rows) {
        root._rows = Array.isArray(rows) ? rows : [];
        hold.restart();
    }

    function stop() {
        hold.stop();
        root._rows = [];
        root._key = "";
        root._queue = [];
        root._wanted = ({});
        proc.running = false;
    }

    function _ext(entry: var): string {
        const raw = String(entry && (entry.path || entry.name) || "");
        const base = raw.slice(raw.lastIndexOf("/") + 1);
        const dot = base.lastIndexOf(".");
        if (dot <= 0 || dot === base.length - 1)
            return "";
        return base.slice(dot + 1).toLowerCase();
    }

    function _has(set: var, ext: var): bool {
        return ext.length > 0 && set.indexOf("|" + ext + "|") >= 0;
    }

    function _thumbable(ext: var): bool {
        return root._has(root._images, ext) || root._has(root._videos, ext) || root._has(root._files, ext);
    }

    function _begin() {
        const rows = root._rows || [];
        const wanted = {};
        const lines = [];
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            if (!row || row.dir)
                continue;
            const path = String(row.path || "");
            if (!path.length || path.indexOf("\n") >= 0 || path.indexOf("\t") >= 0)
                continue;
            if (!root._thumbable(root._ext(row)))
                continue;
            if (wanted[path] || root.map[path])
                continue;
            wanted[path] = true;
            lines.push(path);
        }
        const key = lines.join("\n");
        if (!key.length || key === root._key)
            return;
        root._key = key;
        root._wanted = wanted;
        root._queue = lines;
        root._pump();
    }

    function _pump() {
        if (proc.running || !root._queue.length)
            return;
        const chunk = root._queue.slice(0, 40);
        root._queue = root._queue.slice(40);
        proc.command = [Paths.script("files-thumbs.sh")].concat(chunk);
        proc.running = true;
    }

    function _ingest(line: string) {
        const text = String(line || "");
        const at = text.indexOf("\t");
        if (at <= 0)
            return;
        const src = text.slice(0, at);
        const dest = text.slice(at + 1);
        if (!src.length || !dest.length || !root._wanted[src])
            return;
        const buf = Object.assign({}, root._buf);
        buf[src] = dest;
        root._buf = buf;
        flush.restart();
    }

    function _flush() {
        const buf = root._buf;
        if (!buf || Object.keys(buf).length === 0)
            return;
        root.map = Object.assign({}, root.map, buf);
        root._buf = ({});
        root.rev++;
    }

    Timer {
        id: hold
        interval: Motion.shortMs
        onTriggered: root._begin()
    }

    Timer {
        id: flush
        interval: Motion.shortMs
        onTriggered: root._flush()
    }

    Process {
        id: proc
        stdinEnabled: true
        stdout: SplitParser {
            onRead: (line) => root._ingest(line)
        }
        onExited: {
            root._flush();
            Qt.callLater(root._pump);
        }
    }
}
