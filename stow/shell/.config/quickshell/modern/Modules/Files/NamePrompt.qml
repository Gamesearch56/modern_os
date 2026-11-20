import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    anchors.fill: parent

    open: Files.naming
    titleKey: Files.namingKind === "file" ? "files.newFile" : "files.newFolder"
    confirmKey: "files.create"
    cancelKey: "files.cancel"
    confirmEnabled: root._ok(name.text)
    onCancelled: Files.naming = false
    onConfirmed: Files.create(Files.namingKind, name.text)
    onOpenChanged: {
        if (!root.open)
            return;
        name.text = I18n.t(root.titleKey);
        Qt.callLater(() => {
            name.focusInput();
            name.editor.selectAll();
        });
    }

    MTextField {
        id: name
        Layout.fillWidth: true
        placeholderKey: "files.name"
        onAccepted: {
            if (root.confirmEnabled)
                root.confirmed();
        }
        onEscaped: Files.naming = false
        onActiveFocusChanged: Files.typing = focused
    }

    function _ok(text: string): bool {
        const leaf = String(text || "").trim();
        return leaf.length > 0 && leaf !== "." && leaf !== ".." && leaf.indexOf("/") === -1;
    }
}
