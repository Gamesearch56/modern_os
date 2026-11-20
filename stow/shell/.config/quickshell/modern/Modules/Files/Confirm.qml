import QtQuick
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    anchors.fill: parent
    readonly property bool ejecting: Storage.confirmWhere === "files" && Storage.confirmName.length > 0

    open: Files.confirming || root.ejecting || FilesConflict.open
    titleKey: FilesConflict.open ? "files.exists.title"
        : (root.ejecting ? "files.confirmEject"
        : (Files.confirmKind === "empty" ? "files.confirmEmpty" : "files.confirmDelete"))
    bodyKey: FilesConflict.open ? (FilesConflict.folder ? "files.exists.folder" : "files.exists.file")
        : (root.ejecting ? "files.confirmEjectBody"
        : (Files.confirmKind === "empty" ? "files.confirmEmptyBody" : "files.confirmDeleteBody"))
    bodyParams: FilesConflict.open ? ({ name: FilesConflict.name })
        : (root.ejecting ? ({ name: Storage.confirmLabel }) : ({}))
    confirmKey: FilesConflict.open ? "files.exists.rename"
        : (root.ejecting ? "files.menu.eject"
        : (Files.confirmKind === "empty" ? "files.empty" : "files.delete"))
    cancelKey: "files.cancel"
    destructiveKey: FilesConflict.open ? "files.exists.overwrite" : ""
    destructive: !FilesConflict.open
    cancelLeading: FilesConflict.open
    onCancelled: {
        if (FilesConflict.open)
            FilesConflict.choose("cancel");
        else if (root.ejecting)
            Storage.cancelEject();
        Files.confirming = false;
    }
    onConfirmed: {
        if (FilesConflict.open)
            FilesConflict.choose("keep");
        else if (root.ejecting)
            Storage.commitEject();
        else if (Files.confirmKind === "empty")
            FilesTrash.empty();
        else
            Files.removeSelected();
        Files.confirming = false;
    }
    onDestructiveClicked: FilesConflict.choose("replace")
}
