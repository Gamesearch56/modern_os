import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    anchors.fill: parent

    open: Files.naming
    titleKey: Files.namingKind === "server" ? "files.network.connect"
        : Files.namingKind === "zip" ? "files.zip.title"
        : Files.namingKind === "place" ? "files.exists.rename"
        : Files.namingKind === "file" ? "files.newFile" : "files.newFolder"
    confirmKey: Files.namingKind === "server" ? "files.network.connectDo"
        : Files.namingKind === "zip" ? "files.zip.create"
        : Files.namingKind === "place" ? "files.exists.rename" : "files.create"
    cancelKey: "files.cancel"
    confirmEnabled: root._ok(name.text)
    onCancelled: {
        if (Files.namingKind === "place")
            FilesConflict.abort();
        else
            Files.naming = false;
    }
    onConfirmed: {
        if (Files.namingKind === "server") {
            FilesNet.connect(name.text);
            Files.naming = false;
            return;
        }
        if (Files.namingKind === "zip") {
            FilesZip.pack(name.text);
            return;
        }
        if (Files.namingKind === "place") {
            FilesConflict.named(name.text);
            return;
        }
        Files.create(Files.namingKind, name.text);
    }
    onOpenChanged: {
        if (!root.open)
            return;
        if (Files.namingKind === "place")
            name.text = FilesConflict.suggest;
        else
            name.text = Files.namingKind === "server" || Files.namingKind === "zip" ? "" : I18n.t(root.titleKey);
        Qt.callLater(() => {
            name.focusInput();
            name.editor.selectAll();
        });
    }

    MTextField {
        id: name
        Layout.fillWidth: true
        placeholderKey: Files.namingKind === "server" ? "files.network.address" : Files.namingKind === "zip" ? "files.zip.placeholder" : "files.name"
        selectAllOnPress: Files.namingKind === "place"
        onAccepted: {
            if (root.confirmEnabled)
                root.confirmed();
        }
        onEscaped: Files.naming = false
        onActiveFocusChanged: Files.typing = focused
    }

    function _ok(text: string): bool {
        const leaf = String(text || "").trim();
        if (Files.namingKind === "server")
            return leaf.length > 0 && leaf.indexOf(" ") === -1;
        return leaf.length > 0 && leaf !== "." && leaf !== ".." && leaf.indexOf("/") === -1;
    }
}
