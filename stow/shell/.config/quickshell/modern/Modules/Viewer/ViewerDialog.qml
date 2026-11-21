import QtQuick
import "../../Widgets"

// The viewer's questions: moving the picture to the trash, and notices
// that only explain why something did not happen.
MDialog {
    id: root

    property string kind: ""
    property var params: ({})

    readonly property var _kinds: ({
        trash: { title: "viewer.trash.title", body: "viewer.trash.body", confirm: "viewer.trash.confirm", danger: true },
        notice: { title: "viewer.notice.title", body: "", confirm: "viewer.ok", danger: false }
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
    bodyKey: root.kind === "notice" ? String(root.params.key || "viewer.errors.failed") : root._spec.body
    bodyParams: root.params
    confirmKey: root._spec.confirm
    cancelKey: "viewer.cancel"
    showCancel: root.kind !== "notice"
    destructive: root._spec.danger
    onConfirmed: {
        root.open = false;
        if (root.kind !== "notice")
            root.agreed(root.kind);
    }
    onCancelled: root.open = false
}
