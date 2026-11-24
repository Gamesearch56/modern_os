import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"
import "../../Services/calc.js" as Calc
import "../../Services/command.js" as Command

Scope {
    id: root

    property string query: ""
    property int currentIndex: 0

    IpcHandler {
        target: "launcher"
        function toggle() { Launcher.toggle(); }
        function show() { Launcher.show(); }
        function hide() { Launcher.hide(); }
    }

    readonly property var results: {
        void Config.launcher.frecencyEnabled;
        void Config.launcher.resultCount;
        void Config.launcher.mostUsedGridSize;
        return root.resultsFor(root.query);
    }
    readonly property var catalog: {
        void Launcher.open;
        void DesktopShortcuts.revision;
        const out = root._shellApps();
        const apps = Launcher.catalog("");
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i];
            if (root._isFilesEntry(a.id))
                continue;
            a.kind = "app";
            out.push(a);
        }
        out.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
        return out;
    }
    readonly property var current: {
        if (root.currentIndex < 0 || root.currentIndex >= root.results.length)
            return null;
        return root.results[root.currentIndex];
    }

    function resultsFor(text: string): var {
        const typed = root._typed(text);
        const needle = (text || "").trim().toLowerCase();
        const actions = [];
        if (needle.length > 0) {
            if (root._matchAction(needle, "settings", I18n.t("settings.title")))
                actions.push({ id: "shell:settings", name: I18n.t("settings.title"), genericName: "", icon: "modern-settings-symbolic", kind: "settings" });
            if (root._matchAction(needle, "store", I18n.t("store.title"))
                || root._matchAction(needle, "app store", I18n.t("bar.store")))
                actions.push({ id: "shell:store", name: I18n.t("store.title"), genericName: "", icon: "modern-store-symbolic", kind: "store" });
        }
        const apps = Launcher.query(text);
        const out = [];
        for (let t = 0; t < typed.length; t++)
            out.push(typed[t]);
        for (let i = 0; i < actions.length; i++)
            out.push(actions[i]);
        for (let j = 0; j < apps.length; j++) {
            const a = apps[j];
            a.kind = "app";
            out.push(a);
        }
        return out;
    }

    // Desktop entries never include these shell windows. The file manager
    // also has a desktop file, which the grid skips so it is listed once.
    function _shellApps(): var {
        return [
            { id: "shell:settings", name: I18n.t("settings.title"), genericName: "", icon: "modern-settings-symbolic", tint: true, kind: "settings" },
            { id: "shell:store", name: I18n.t("store.title"), genericName: "", icon: "modern-store-symbolic", tint: true, kind: "store" },
            { id: "shell:files", name: I18n.t("files.launcherName"), genericName: "", icon: "modern-files-symbolic", tint: true, kind: "files" }
        ];
    }

    function _isFilesEntry(id: string): bool {
        return String(id || "").replace(/\.desktop$/i, "") === "modern.files";
    }

    function _matchAction(needle: string, english: string, title: string): bool {
        const n = needle.toLowerCase();
        const en = english.toLowerCase();
        const t = (title || "").toLowerCase();
        return en.indexOf(n) !== -1 || t.indexOf(n) !== -1 || n.indexOf(en) !== -1;
    }

    function _typed(text: string): var {
        const providers = (Config.launcher && Config.launcher.providers) || {};
        const calcP = providers.calculator || {};
        const shellP = providers.shell || {};
        const out = [];
        if (calcP.enabled !== false) {
            const value = Calc.offer(text, calcP.prefix);
            if (value !== null)
                out.push({ id: "calc:" + value, name: value, genericName: I18n.t("launcher.copyResult"),
                    icon: "accessories-calculator", kind: "calc" });
        }
        if (shellP.enabled !== false) {
            const argv = Command.offer(text, shellP.prefix);
            if (argv)
                out.push({ id: "cmd:" + argv.join(" "), name: argv.join(" "),
                    genericName: I18n.t("launcher.runCommand"), icon: "utilities-terminal",
                    kind: "command", argv: argv });
        }
        return out;
    }

    function activate(item: var) {
        if (!item)
            return;
        if (item.kind === "calc") {
            Quickshell.clipboardText = String(item.name || "");
            Launcher.hide();
            return;
        }
        if (item.kind === "command") {
            Launcher.runCommand(item.argv);
            return;
        }
        if (item.kind === "settings") {
            Settings.show();
            Launcher.hide();
            return;
        }
        if (item.kind === "store") {
            Store.show();
            Launcher.hide();
            return;
        }
        if (item.kind === "files") {
            Files.show("");
            Launcher.hide();
            return;
        }
        Launcher.launch(item);
    }

    function _focusedScreen(): var {
        const n = Hypr.focusedMonitorName();
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === n)
                return screens[i];
        }
        return screens.length ? screens[0] : null;
    }

    LazyLoader {
        active: Launcher.open

        PanelWindow {
            id: win
            property real _grabAt: 0
            property int _rearm: 0
            visible: Launcher.open
            screen: root._focusedScreen()
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            // Leave the dock's edge clear so pins can be grabbed while this overlay is open.
            margins.top: DockLayout.enabled && DockLayout.position === "top" ? DockLayout.cross : 0
            margins.bottom: DockLayout.enabled && DockLayout.position === "bottom" ? DockLayout.cross : 0
            margins.left: DockLayout.enabled && DockLayout.position === "left" ? DockLayout.cross : 0
            margins.right: DockLayout.enabled && DockLayout.position === "right" ? DockLayout.cross : 0
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay

            Overlay {
                id: overlay
                anchors.fill: parent
                query: root.query
                results: root.results
                catalog: root.catalog
                currentIndex: root.currentIndex
                onQueryEdited: (t) => {
                    root.query = t;
                    root.currentIndex = 0;
                }
                onPicked: (i) => root.currentIndex = i
                onActivated: (i) => {
                    root.currentIndex = i;
                    root.activate(root.results[i]);
                }
                onActivatedApp: (i) => {
                    const item = root.catalog[i];
                    if (item)
                        root.activate(item);
                }
                onClosed: Launcher.hide()
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: Popups.grabWindows(win, win.screen)
                onCleared: {
                    if (!Launcher.open)
                        return;
                    // The dock joins this grab and steps up to the overlay
                    // layer as the launcher opens. That clears the grab once.
                    if (win._rearm < 1 && Date.now() - win._grabAt < Motion.mediumMs) {
                        win._rearm = 1;
                        Qt.callLater(() => {
                            if (!Launcher.open)
                                return;
                            keyGrab.active = true;
                            overlay.focusSearch();
                        });
                        return;
                    }
                    Launcher.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: {
                    if (!overlay.takeEscape())
                        Launcher.hide();
                }
            }

            Component.onCompleted: {
                root.query = "";
                root.currentIndex = 0;
                Qt.callLater(() => {
                    if (!Launcher.open)
                        return;
                    win._grabAt = Date.now();
                    keyGrab.active = true;
                    overlay.focusSearch();
                });
            }
        }
    }
}
