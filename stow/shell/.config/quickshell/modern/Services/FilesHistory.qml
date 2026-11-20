pragma Singleton
import Quickshell
import QtQuick
import "../Commons"

// Back and forward across folders and the sidebar places.
Singleton {
    id: root

    property var back: []
    property var forward: []
    // The side button also lands on the icon under the pointer. That press
    // is navigation, not a click on the file, and the resting pointer is
    // not a folder that was opened.
    property double sideAt: 0
    property bool _sideOnce: false
    property bool pinHover: false
    property real pinX: -1
    property real pinY: -1
    // A reload starts at home. The saved folder is only a marker that
    // startup has finished, so a listing cannot race that decision.
    property bool placeReady: false

    function notePlace(raw: string, done: bool): bool {
        if (root.placeReady)
            return true;
        const saved = String(raw || "").trim();
        if (saved.charAt(0) !== "/" && !done)
            return true;
        root.placeReady = true;
        if (Quickshell.env("MODERN_FILE_WINDOW"))
            return true;
        const home = String(Paths.home || "");
        if (home.charAt(0) !== "/")
            return true;
        Files._resume = home;
        // A request already chose a folder. Sending Home first makes the
        // window open there and only then step to that folder.
        if (Files.open && Files.path !== home)
            return true;
        if (!Files.path.length || Files.path === home)
            Files.path = home;
        else
            Files._openAt(home);
        return true;
    }

    // The icon and the window both see one side click. The second delivery
    // is the same click, not another step.
    function sideStep(backward: bool) {
        if (root._sideOnce)
            return;
        if (!Files.open || Files.propertiesOpen || Files.confirming || Files.naming || FilesConflict.open || Files.covered || Storage.confirmWhere === "files")
            return;
        root._sideOnce = true;
        root.sideAt = Date.now();
        if (backward)
            Files.back();
        else
            Files.forward();
        Qt.callLater(() => { root._sideOnce = false; });
    }

    function pinLocation() {
        root.pinHover = true;
        root.pinX = -1;
        root.pinY = -1;
        Files.hoverPath = "";
    }

    function openFolder(folder: string, push: bool, pick: var) {
        const next = String(folder || "");
        if (next.charAt(0) !== "/")
            return;
        const spot = Files._spot();
        const changed = !(spot.place === "folder" && spot.path === next);
        if (push && changed)
            root._push(spot);
        Files._arrive("folder", next, pick);
        if (push && changed)
            FilesUndo.noteRoute(spot, Files._spot());
    }

    function openPlace(kind: string) {
        const next = String(kind || "");
        if (!next.length || next === "folder" || next === Files.place)
            return;
        const spot = Files._spot();
        root._push(spot);
        Files._arrive(next, Files.path, []);
        FilesUndo.noteRoute(spot, Files._spot());
    }

    function up() {
        if (Files.place !== "folder" || Files.path === "/")
            return;
        const slash = Files.path.lastIndexOf("/");
        root.openFolder(slash > 0 ? Files.path.slice(0, slash) : "/", true, []);
    }

    function travel(backward: bool) {
        const from = Files._spot();
        const entry = root._pop(backward, from);
        if (!entry)
            return;
        const place = String(entry.place || "folder");
        Files._arrive(place, String(entry.path || ""), place === "folder" ? entry.pick : []);
        FilesUndo.noteRoute(from, Files._spot());
    }

    function restore(spot: var) {
        const target = spot || {};
        const place = String(target.place || "folder");
        const path = String(target.path || "");
        const current = Files._spot();
        if (root._same(current, target))
            return;
        if (root.back.length && root._same(root.back[root.back.length - 1], target)) {
            root.travel(true);
            return;
        }
        if (root.forward.length && root._same(root.forward[root.forward.length - 1], target)) {
            root.travel(false);
            return;
        }
        root.forward = root.forward.concat([current]);
        Files._arrive(place, path, place === "folder" ? (target.pick || []) : []);
    }

    function reject() {
        const stack = root.back.slice();
        if (!stack.length)
            return null;
        const entry = stack.pop();
        root.back = stack;
        return entry;
    }

    function _same(a: var, b: var): bool {
        return String((a || {}).place || "") === String((b || {}).place || "") && String((a || {}).path || "") === String((b || {}).path || "");
    }

    function _push(spot: var) {
        root.back = root.back.concat([spot]);
        root.forward = [];
    }

    function _pop(backward: bool, spot: var) {
        const from = (backward ? root.back : root.forward).slice();
        if (!from.length)
            return null;
        const entry = from.pop();
        if (backward) {
            root.back = from;
            root.forward = root.forward.concat([spot]);
        } else {
            root.forward = from;
            root.back = root.back.concat([spot]);
        }
        return entry;
    }
}
