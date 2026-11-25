import QtQuick
import "../../Widgets"
import "../../Services"

MDialog {
    anchors.fill: parent

    open: FilesSaveAs.replacing
    titleKey: "files.pick.replaceTitle"
    bodyKey: "files.pick.replaceBody"
    bodyParams: ({ name: FilesSaveAs.leaf })
    confirmKey: "files.pick.replace"
    cancelKey: "files.cancel"
    destructive: true
    onConfirmed: FilesSaveAs.replace()
    onCancelled: FilesSaveAs.keep()
}
