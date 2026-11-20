import QtQuick
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    anchors.fill: parent
    readonly property bool ejecting: Storage.confirmWhere === "files" && Storage.confirmName.length > 0

    open: Files.confirming || root.ejecting
    titleKey: root.ejecting ? "files.confirmEject"
        : (Files.confirmKind === "empty" ? "files.confirmEmpty" : "files.confirmDelete")
    bodyKey: root.ejecting ? "files.confirmEjectBody"
        : (Files.confirmKind === "empty" ? "files.confirmEmptyBody" : "files.confirmDeleteBody")
    bodyParams: root.ejecting ? ({ name: Storage.confirmLabel }) : ({})
    confirmKey: root.ejecting ? "files.menu.eject"
        : (Files.confirmKind === "empty" ? "files.empty" : "files.delete")
    cancelKey: "files.cancel"
    destructive: true
    onCancelled: {
        if (root.ejecting)
            Storage.cancelEject();
        Files.confirming = false;
    }
    onConfirmed: {
        if (root.ejecting)
            Storage.commitEject();
        else if (Files.confirmKind === "empty")
            FilesTrash.empty();
        else
            Files.removeSelected();
        Files.confirming = false;
    }
}
