// Deep-link bus for Settings. Widgets call openAt("audio") instead of
// constructing Modules/Settings — keeps the layer rule (no Module→Module
// internals) and gives every "open settings" button one primitive.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false
    property string sectionId: "general"
    property string subsectionId: ""

    function openAt(section: string, subsection: string) {
        root.sectionId = section || "general";
        root.subsectionId = subsection || "";
        root.open = true;
    }

    function close() {
        root.open = false;
    }

    IpcHandler {
        target: "settings"
        function open() { root.openAt("general", ""); }
        function openAt(section: string) { root.openAt(section, ""); }
    }
}
