import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Scope {
    id: root
    IpcHandler {
        target: "launcher"
        function toggle() { Launcher.toggle(); }
        function show() { Launcher.show(); }
        function hide() { Launcher.hide(); }
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

        PanelWindow {
            id: win
            visible: Launcher.open
            color: "transparent"
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            MOverlay {
                id: overlay
                open: Launcher.open
                titleKey: "bar.launcher"
                cardWidth: Tokens.spacing.xxl * 16
                cardHeight: Tokens.spacing.xxl * 14
                onClosed: Launcher.hide()

                ColumnLayout {
                    spacing: Tokens.spacing.md

                    MSearchField {
                        id: query
                        Layout.fillWidth: true
                        placeholderKey: "launcher.placeholder"
                        Component.onCompleted: forceActiveFocus()
                        onAccepted: root.activate(list.model[list.currentIndex] || list.model[0])
                        onTextEdited: list.currentIndex = 0
                        onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                        onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                    }

                    MText {
                        visible: query.text.length === 0
                        key: "launcher.mostUsed"
                        styleName: "labelLarge"
                        color: Colors.color.onSurfaceVariant
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Tokens.spacing.sm
                        model: root.resultsFor(query.text)
                        currentIndex: 0
                        delegate: MListItem {
                            required property var modelData
                            required property int index
                            width: list.width
                            iconName: modelData.icon || "application-x-executable"
                            tintIcon: modelData.kind === "settings" || modelData.kind === "power"
                            titleValue: modelData.name
                            subtitleValue: modelData.genericName || ""
                            selected: list.currentIndex === index
                            onClicked: root.activate(modelData)
                        }

                        MEmptyState {
                            visible: list.count === 0 && query.text.length > 0
                            anchors.fill: parent
                            iconName: "edit-find-symbolic"
                            titleKey: "launcher.noResults"
                        }
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
