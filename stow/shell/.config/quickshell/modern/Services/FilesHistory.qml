pragma Singleton
import Quickshell
import QtQuick
import "../Commons"

// Back and forward across folders and the sidebar places.
Singleton {
    id: root

    property var back: []
    property var forward: []
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
        if (!Files.path.length || Files.path === home)
            Files.path = home;
        else
            Files._openAt(home);
        return true;
    }

    function openFolder(folder: string, push: bool, pick: var) {
        const next = String(folder || "");
        if (next.charAt(0) !== "/")
            return;
        const spot = Files._spot();
        if (push && !(spot.place === "folder" && spot.path === next))
            root._push(spot);
        Files._arrive("folder", next, pick);
    }

    function openPlace(kind: string) {
        const next = String(kind || "");
        if (!next.length || next === "folder" || next === Files.place)
            return;
        root._push(Files._spot());
        Files._arrive(next, Files.path, []);
    }

    function up() {
        if (Files.place !== "folder" || Files.path === "/")
            return;
        const slash = Files.path.lastIndexOf("/");
        root.openFolder(slash > 0 ? Files.path.slice(0, slash) : "/", true, []);
    }

    function travel(backward: bool) {
        const entry = root._pop(backward, Files._spot());
        if (!entry)
            return;
        const place = String(entry.place || "folder");
        Files._arrive(place, String(entry.path || ""), place === "folder" ? entry.pick : []);
    }

    function reject() {
        const stack = root.back.slice();
        if (!stack.length)
            return null;
        const entry = stack.pop();
        root.back = stack;
        return entry;
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
