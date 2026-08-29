import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
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

    readonly property var results: root.resultsFor(root.query)
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
            Settings.openAt("general", "");
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

    LazyLoader {
        active: Launcher.open

        FloatingWindow {
            id: win
            visible: Launcher.open
            title: "modern.launcher"
            color: Colors.color.surface
            implicitWidth: Tokens.spacing.xxl * 32 + Tokens.spacing.lg
            implicitHeight: Tokens.spacing.xxl * 22 + Tokens.spacing.lg

            onVisibleChanged: {
                if (visible) {
                    root.query = "";
                    root.currentIndex = 0;
                    win.requestActivate();
                } else if (Launcher.open) {
                    Launcher.hide();
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.color.surface
                radius: Tokens.radius.medium
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.md
                spacing: Tokens.spacing.md

                MWindowChrome {
                    Layout.fillWidth: true
                    titleKey: "bar.launcher"
                    subtitleValue: User.displayName
                    titleColumnWidth: Tokens.spacing.xxl * 9
                    onClosed: Launcher.hide()
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.lg

                    MPane {
                        Layout.preferredWidth: Tokens.spacing.xxl * 9
                        Layout.fillHeight: true

                        Nav {
                            anchors.fill: parent
                            model: root.results
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
                        }
                    }

                    Detail {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        item: root.current
                        searching: root.query.trim().length > 0
                        onConfirmed: root.activate(root.current)
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Launcher.hide()
            }
        }
    }
}
