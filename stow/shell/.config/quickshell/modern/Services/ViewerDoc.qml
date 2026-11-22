pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// The Imageviewer's pictures: the list to step through, the current one,
// its facts from viewer-io (size, type, mtime), and the view turn not yet
// saved. Stepping wraps around at both ends, like imv. Every refusal from
// viewer-io becomes `notice` (a translation key) for the window to show.
Singleton {
    id: root

    readonly property var _knownErrors: ["missing", "directory", "special", "empty", "denied", "readOnlyFs",
        "full", "badName", "changed", "unsupported", "tooLarge", "protected"]

    property var items: []
    property int index: -1
    property var info: ({})
    property int rotation: 0
    property bool failed: false
    property bool paused: false
    property bool slideshow: false
    property int revision: 0
    property string notice: ""
    property var noticeParams: ({})

    readonly property int count: root.items.length
    readonly property bool empty: root.count === 0
    readonly property string path: root.index >= 0 && root.index < root.count ? String(root.items[root.index]) : ""
    readonly property string name: root.path.length ? root.path.slice(root.path.lastIndexOf("/") + 1) : ""
    readonly property string folder: root.path.length ? (root.path.slice(0, root.path.lastIndexOf("/")) || "/") : ""
    readonly property bool busy: ViewerIo.busy

    signal shown()

    // Params first: the window reacts to `notice` the moment it changes.
    function _say(error: string) {
        root.noticeParams = { name: root.name };
        root.notice = "viewer.errors." + (root._knownErrors.indexOf(error) >= 0 ? error : "failed");
    }

    function clearNotice() {
        root.notice = "";
        root.noticeParams = ({});
    }

    // Paths, file:// URIs, or folders, as the launcher or a drop gives them.
    function open(paths: var) {
        const list = (paths || []).map(p => String(p)).filter(p => p.length);
        if (!list.length)
            return;
        ViewerIo.run(["list"].concat(list), (out) => {
            if (!out.ok) {
                root._say(out.error);
                return;
            }
            root.items = out.items;
            root._go(out.index);
        });
    }

    function _go(i: int) {
        if (!root.count) {
            root.index = -1;
            root.info = ({});
            return;
        }
        root.index = ((i % root.count) + root.count) % root.count;
        root.rotation = 0;
        root.failed = false;
        root.paused = false;
        root.info = ({});
        const wanted = root.path;
        ViewerIo.run(["info", wanted], (out) => {
            if (root.path === wanted && out.ok)
                root.info = out;
        });
        root.shown();
    }

    function next() { root._go(root.index + 1); }
    function previous() { root._go(root.index - 1); }
    function first() { root._go(0); }
    function last() { root._go(root.count - 1); }

    // Drops the picture from this window's list only, like imv's close.
    function remove() {
        if (root.empty)
            return;
        const at = root.index;
        const next = root.items.slice();
        next.splice(at, 1);
        root.items = next;
        root._go(Math.min(at, next.length - 1));
    }

    function rotate(quarterTurns: int) {
        root.rotation = (((root.rotation + quarterTurns * 90) % 360) + 360) % 360;
    }

    function saveRotation(done: var) {
        if (!root.rotation || !root.path.length)
            return;
        const wanted = root.path;
        const turn = root.rotation;
        const args = ["rotate", wanted, String(turn)];
        if (root.info.mtime)
            args.push("--expect", String(root.info.mtime));
        ViewerIo.run(args, (out) => {
            if (!out.ok) {
                root._say(out.error);
            } else if (root.path === wanted) {
                root.info = Object.assign({}, root.info, { mtime: out.mtime, size: out.size });
                root.rotation = 0;
                root.revision++;
            }
            if (done)
                done(out.ok);
        });
    }

    function trash(done: var) {
        const wanted = root.path;
        if (!wanted.length)
            return;
        ViewerIo.run(["trash", wanted], (out) => {
            if (!out.ok)
                root._say(out.error);
            else if (root.path === wanted)
                root.remove();
            if (done)
                done(out.ok);
        });
    }

    function copyImage() {
        if (root.path.length)
            ViewerIo.run(["copy", root.path], (out) => { if (!out.ok) root._say(out.error); });
    }

    function copyPath() {
        if (root.path.length)
            ViewerIo.run(["copy-path", root.path], (out) => { if (!out.ok) root._say(out.error); });
    }

    function reveal() {
        if (root.path.length)
            Quickshell.execDetached(["qs", "-c", "modern", "ipc", "call", "files", "reveal", root.path]);
    }

    function openWindow() {
        Quickshell.execDetached([Paths.script("modern-imageviewer")]);
    }

    // The window is always the focused one when its own key asks for this.
    function toggleFullscreen() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen()"]);
    }

    function setSlideshow(on: bool) {
        root.slideshow = on && root.count > 1;
    }

    Timer {
        interval: ViewerPrefs.slideshowSeconds * 1000
        repeat: true
        running: root.slideshow && root.count > 1
        onTriggered: root.next()
    }
}
