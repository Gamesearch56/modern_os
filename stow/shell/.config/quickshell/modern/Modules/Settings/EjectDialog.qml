import QtQuick
import QtQuick.Window
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    anchors.fill: parent
    // Same as the cleanup dialog: the window is not the parent yet.
    Binding {
        when: root.Window.window !== null
        target: root
        property: "parent"
        value: root.Window.window ? root.Window.window.contentItem : root.parent
        restoreMode: Binding.RestoreNone
    }

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
