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
    property string _returnSection: ""
    property string _returnSub: ""
    property string _returnDetail: ""
    // One-shot page detail, such as which calendar was open.
    property string restoreDetail: ""

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
        if (id === "games")
            return "gaming";
        return id;
    }

    function openAt(section: string, subsection: string) {
        root._returnSection = "";
        root._returnSub = "";
        root._returnDetail = "";
        root.restoreDetail = "";
        root._apply(section, subsection);
    }

    function _apply(section: string, subsection: string) {
        if (section === "privacy" && subsection === "calendar") {
            section = "bar";
            subsection = "clock";
        }
        const id = root.resolve(section);
        root.sectionId = id;
        root.subsectionId = subsection || "";
        if (id === "design" && (section === "windows" || subsection === "windows"))
            root.subsectionId = "windows";
        root.open = true;
    }

    function close() {
        ConfigWrite.flush();
        root.open = false;
    }

    // Close now, and open this page the next time Settings is shown.
    // detail is restored with the page (the calendar that was open).
    function reopenAt(section: string, subsection: string, detail: string) {
        root._returnSection = section || "";
        root._returnSub = subsection || "";
        root._returnDetail = detail || "";
        root.close();
    }

    function show() {
        if (!root._returnSection.length) {
            root.open = true;
            return;
        }
        const section = root._returnSection;
        const sub = root._returnSub;
        const detail = root._returnDetail;
        root._returnSection = "";
        root._returnSub = "";
        root._returnDetail = "";
        root.restoreDetail = detail;
        root._apply(section, sub);
    }

    function toggle() {
        if (root.open)
            root.close();
        else
            root.show();
    }

    IpcHandler {
        target: "settings"
        function open() { root.show(); }
        function openAt(section: string) { root.openAt(section, ""); }
        function close() { root.close(); }
        function toggle() { root.toggle(); }
    }
}
