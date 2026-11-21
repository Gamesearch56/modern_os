pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

// The Mediaplayer's playlist: the files to step through and the current
// one. A video opens the other videos of its folder, a song the other songs
// (player-io list). Stepping wraps around at both ends. Every refusal from
// player-io becomes `notice` (a translation key) for the window to show;
// `saved` reports a frame written to Pictures.
Singleton {
    id: root

    readonly property var _knownErrors: ["missing", "directory", "special", "empty", "denied", "readOnlyFs",
        "full", "badName", "unsupported", "tooLarge"]

    property var items: []
    property int index: -1
    property string notice: ""
    property var noticeParams: ({})

    readonly property int count: root.items.length
    readonly property bool empty: root.count === 0
    readonly property string path: root.index >= 0 && root.index < root.count ? String(root.items[root.index]) : ""
    readonly property string name: root.path.length ? root.path.slice(root.path.lastIndexOf("/") + 1) : ""
    readonly property string folder: root.path.length ? (root.path.slice(0, root.path.lastIndexOf("/")) || "/") : ""
    readonly property string screenshots: XdgDirs.pictures + "/Screenshots"
    readonly property bool busy: PlayerIo.busy

    signal shown()
    signal saved(string path)

    // Params first: the window reacts to `notice` the moment it changes.
    function _say(error: string) {
        root.noticeParams = { name: root.name };
        root.notice = "player.errors." + (root._knownErrors.indexOf(error) >= 0 ? error : "failed");
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
        PlayerIo.run(["list"].concat(list), (out) => {
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
            return;
        }
        root.index = ((i % root.count) + root.count) % root.count;
        root.shown();
    }

    function next() { root._go(root.index + 1); }
    function previous() { root._go(root.index - 1); }

    function screenshot(milliseconds: real) {
        if (!root.path.length)
            return;
        PlayerIo.run(["frame", root.path, String(Math.max(0, Math.round(milliseconds))), root.screenshots], (out) => {
            if (out.ok)
                root.saved(out.path);
            else
                root._say(out.error);
        });
    }

    function copyPath() {
        if (root.path.length)
            PlayerIo.run(["copy-path", root.path], (out) => { if (!out.ok) root._say(out.error); });
    }

    function reveal() {
        if (root.path.length)
            Quickshell.execDetached(["qs", "-c", "modern", "ipc", "call", "files", "reveal", root.path]);
    }

    function openWindow() {
        Quickshell.execDetached([Paths.script("modern-mediaplayer")]);
    }

    // The window is always the focused one when its own key asks for this.
    function toggleFullscreen() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen()"]);
    }
}
