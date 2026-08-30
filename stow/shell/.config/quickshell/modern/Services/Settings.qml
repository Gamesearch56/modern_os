// Deep-link bus for Settings. Widgets call openAt("audio") instead of
// constructing Modules/Settings — keeps the layer rule (no Module→Module
// internals) and gives every "open settings" button one primitive.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false
    property string sectionId: "overview"
    property string subsectionId: ""

    function resolve(section: string): string {
        const id = section || "overview";
        if (id === "general")
            return "overview";
        if (id === "time")
            return "language";
        if (id === "accounts")
            return "privacy";
        if (id === "widgets")
            return "bar";
        if (id === "windows")
            return "design";
        if (id === "display")
            return "displays";
        if (id === "screenshot")
            return "screenshots";
        if (id === "gaming")
            return "overview";
        return id;
    }

    function openAt(section: string, subsection: string) {
        const id = root.resolve(section);
        root.sectionId = id;
        root.subsectionId = subsection || "";
        if (id === "design" && (section === "windows" || subsection === "windows"))
            root.subsectionId = "windows";
        root.open = true;
    }

    function close() {
        root.open = false;
    }

    function toggle() {
        if (root.open)
            root.close();
        else
            root.openAt("overview", "");
    }

    IpcHandler {
        target: "settings"
        function open() { root.openAt("overview", ""); }
        function openAt(section: string) { root.openAt(section, ""); }
        function close() { root.close(); }
        function toggle() { root.toggle(); }
    }
}
