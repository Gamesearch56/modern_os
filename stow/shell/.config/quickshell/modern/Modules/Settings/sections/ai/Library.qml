import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg
    Layout.fillWidth: true

    property string pendingDelete: ""

    function _activeName(): string {
        return String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "");
    }

    function _inUse(name: string): bool {
        const n = String(name || "").replace(/:latest$/, "");
        return n.length > 0 && n === root._activeName();
    }

    property var opened: ({})

    Grouper { id: grouper }

    readonly property var groups: {
        void Ai.models;
        void library.results;
        void library.tags;
        void search.text;
        void Config.accounts?.ai?.ollamaModel;
        return grouper.build(Ai.models, library.results, library.tags, search.text, root._activeName());
    }

    function _isOpen(family: string): bool {
        return !!root.opened[family];
    }

    function _toggle(family: string) {
        const next = {};
        const cur = root.opened || {};
        for (const k in cur)
            next[k] = cur[k];
        const will = !root._isOpen(family);
        next[family] = will;
        root.opened = next;
        if (will)
            library.loadTags(family);
    }

    function _schedule() {
        hold.restart();
    }

    AiLibrary { id: library }

    Timer {
        id: hold
        interval: Motion.durationLong
        repeat: false
        onTriggered: library.search(search.text.trim())
    }

    Component.onCompleted: {
        root._schedule();
        root._rate();
    }

    onGroupsChanged: root._rate()

    Connections {
        target: library
        function onRamBytesChanged() { root._rate(); }
        function onVramBytesChanged() { root._rate(); }
    }

    function _rate() {
        const names = [];
        const list = root.groups || [];
        for (let i = 0; i < list.length; i++) {
            const tags = list[i].tags || [];
            for (let j = 0; j < tags.length; j++)
                names.push(tags[j].name);
        }
        library.rate(names);
    }

    Connections {
        target: library
        function onFinished(action, name, ok) {
            Ai.refreshStatus();
            if (!ok || !name.length)
                return;
            if (action === "pull")
                return;
            const cur = String(Config.accounts?.ai?.ollamaModel || "").replace(/:latest$/, "");
            if (cur !== name)
                return;
            const list = Ai.models || [];
            let next = "";
            for (let i = 0; i < list.length; i++) {
                const stem = String(list[i] || "").replace(/:latest$/, "");
                if (stem.length && stem !== name) {
                    next = stem;
                    break;
                }
            }
            ConfigWrite.set("accounts.ai.ollamaModel", next);
        }
    }

    MField {
        labelKey: "settings.fields.aiLibrary"
        hintKey: "settings.hints.aiLibrary"
        MSearchField {
            id: search
            placeholderKey: "settings.ollama.search"
            onTextEdited: root._schedule()
        }
    }

    MHint {
        visible: !Ai.running
        key: "settings.ollama.needRunning"
        Layout.fillWidth: true
    }
    MLinearProgress {
        visible: !library.ready || library.searching
        Layout.fillWidth: true
        indeterminate: true
    }
    MHint {
        visible: library.ready && library.failed && !library.searching && !library.busyName.length
        key: "settings.ollama.actionFailed"
        Layout.fillWidth: true
    }
    MHint {
        visible: library.ready && !library.searching && !library.failed && root.groups.length === 0
        key: "settings.ollama.empty"
        Layout.fillWidth: true
    }

    Repeater {
        model: library.ready && !library.searching ? root.groups : []
        delegate: ModelGroup {
            required property var modelData
            family: modelData.family
            desc: modelData.desc
            use: modelData.use || "chat"
            also: modelData.also || []
            tags: modelData.tags
            fit: library.fit
            busyName: library.busyName
            canInstall: Ai.running
            expanded: root._isOpen(modelData.family) && (modelData.tags || []).length > 0
            onToggled: root._toggle(modelData.family)
            onInstall: (name) => library.pull(name)
            onAskRemove: (name) => {
                if (!root._inUse(name))
                    root.pendingDelete = name;
            }
        }
    }

    JobOverlay {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        action: library.jobAction
        name: library.jobName
        log: library.jobLog
        state: library.jobState
        onDismiss: library.dismissJob()
    }

    MDialog {
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        open: root.pendingDelete.length > 0
        titleKey: "settings.ollama.deleteTitle"
        titleParams: ({ name: root.pendingDelete })
        bodyKey: "settings.ollama.deleteBody"
        bodyParams: ({ name: root.pendingDelete })
        confirmKey: "settings.ollama.deleteModel"
        cancelKey: "settings.cancel"
        destructive: true
        confirmEnabled: !library.busyName.length
        onConfirmed: {
            const name = root.pendingDelete;
            root.pendingDelete = "";
            if (!root._inUse(name))
                library.remove(name);
        }
        onCancelled: root.pendingDelete = ""
    }
}
