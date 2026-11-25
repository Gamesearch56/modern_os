import QtQuick
import "../../Widgets"
import "../../Services"

// The editor's smaller questions, one table instead of one file each.
// "notice" only explains; the others confirm a step Flow then takes.
MDialog {
    id: root

    property string kind: ""
    property var params: ({})

    readonly property var _kinds: ({
        changed: { title: "editor.changed.title", body: "editor.changed.body", confirm: "editor.changed.overwrite", danger: true },
        exists: { title: "editor.exists.title", body: "editor.exists.body", confirm: "editor.exists.replace", danger: true },
        trash: { title: "editor.trash.title", body: "editor.trash.body", confirm: "editor.trash.confirm", danger: true },
        notice: { title: "editor.notice.title", body: "", confirm: "editor.ok", danger: false }
    })
    readonly property var _spec: root._kinds[root.kind] || root._kinds.notice

    signal agreed(string kind)

    function ask(kind: string, params: var) {
        root.kind = kind;
        root.params = params || ({});
        root.open = true;
    }

    anchors.fill: parent
    titleKey: root._spec.title
    bodyKey: root.kind === "notice" ? String(root.params.key || "editor.errors.failed") : root._spec.body
    bodyParams: root.params
    confirmKey: root._spec.confirm
    cancelKey: "editor.cancel"
    showCancel: root.kind !== "notice"
    destructive: root._spec.danger
    onConfirmed: {
        root.open = false;
        if (root.kind !== "notice")
            root.agreed(root.kind);
    }
    onCancelled: root.open = false
}
