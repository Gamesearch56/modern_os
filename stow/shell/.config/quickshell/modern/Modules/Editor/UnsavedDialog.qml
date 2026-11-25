import QtQuick
import "../../Widgets"
import "../../Services"

// Save, don't save, or stay — before New, Open, or closing the window.
MDialog {
    id: root

    signal save()
    signal discard()

    anchors.fill: parent
    titleKey: "editor.unsaved.title"
    bodyKey: "editor.unsaved.body"
    bodyParams: ({ name: EditorDoc.name })
    confirmKey: "editor.unsaved.save"
    destructiveKey: "editor.unsaved.discard"
    cancelKey: "editor.cancel"
    cancelLeading: true
    busy: EditorDoc.busy
    onConfirmed: root.save()
    onDestructiveClicked: root.discard()
    onCancelled: root.open = false
}
