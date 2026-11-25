import QtQuick
import QtQuick.Window
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    // A direct child of the Settings FloatingWindow, so the parent is
    // already its content item.
    anchors.fill: parent
    open: Storage.confirmWhere === "settings" && Storage.confirmName.length > 0
    titleKey: "files.confirmEject"
    bodyKey: "files.confirmEjectBody"
    bodyParams: ({ name: Storage.confirmLabel })
    confirmKey: "settings.storage.eject"
    cancelKey: "settings.cancel"
    destructive: true
    onConfirmed: Storage.commitEject()
    onCancelled: Storage.cancelEject()
}
