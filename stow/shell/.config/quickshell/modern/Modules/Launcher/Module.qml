import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../Commons"
import "../../Services"

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
    readonly property var current: {
        if (root.currentIndex < 0 || root.currentIndex >= root.results.length)
            return null;
        return root.results[root.currentIndex];
    }

    function resultsFor(text: string): var {
        const needle = (text || "").trim().toLowerCase();
        const actions = [];
        if (needle.length > 0) {
            if (root._matchAction(needle, "settings", I18n.t("settings.title")))
                actions.push({ id: "shell:settings", name: I18n.t("settings.title"), genericName: "", icon: "preferences-system", kind: "settings" });
            if (root._matchAction(needle, "store", I18n.t("store.title"))
                || root._matchAction(needle, "app store", I18n.t("bar.store")))
                actions.push({ id: "shell:store", name: I18n.t("store.title"), genericName: "", icon: "plasmadiscover", kind: "store" });
            if (root._matchAction(needle, "power", I18n.t("powerMenu.title")))
                actions.push({ id: "shell:power", name: I18n.t("powerMenu.title"), genericName: "", icon: "system-shutdown", kind: "power" });
        }
        const apps = Launcher.query(text);
        const out = [];
        for (let i = 0; i < actions.length; i++)
            out.push(actions[i]);
        for (let j = 0; j < apps.length; j++) {
            const a = apps[j];
            a.kind = "app";
            out.push(a);
        }
        return out;
    }

    function _matchAction(needle: string, english: string, title: string): bool {
        const n = needle.toLowerCase();
        const en = english.toLowerCase();
        const t = (title || "").toLowerCase();
        return en.indexOf(n) !== -1 || t.indexOf(n) !== -1 || n.indexOf(en) !== -1;
    }

    function activate(item: var) {
        if (!item)
            return;
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
        if (item.kind === "power") {
            PowerMenu.toggle();
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
            visible: Launcher.open
            screen: root._focusedScreen()
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay

            Overlay {
                id: overlay
                anchors.fill: parent
                query: root.query
                results: root.results
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
                onClosed: Launcher.hide()
            }

            HyprlandFocusGrab {
                id: keyGrab
                windows: Popups.grabWindows(win, win.screen)
                onCleared: {
                    if (Launcher.open)
                        Launcher.hide();
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: Launcher.hide()
            }

            Component.onCompleted: {
                root.query = "";
                root.currentIndex = 0;
                Qt.callLater(() => {
                    if (!Launcher.open)
                        return;
                    keyGrab.active = true;
                    overlay.focusSearch();
                });
            }
        }
    }
}
