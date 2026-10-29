import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../Commons"
import "../../Widgets"
import "../../Services"

MDialog {
    id: root

    parent: Window.window ? Window.window.contentItem : root
    anchors.fill: parent
    open: StorageClean.open
    wide: true
    titleKey: StorageClean.phase === "done"
        ? "settings.storage.cleanDoneTitle"
        : "settings.storage.cleanTitle"
    bodyKey: StorageClean.phase === "ask" ? "settings.storage.cleanBody" : ""
    confirmKey: StorageClean.phase === "done" ? "bar.close" : "settings.storage.cleanConfirm"
    cancelKey: "settings.cancel"
    showCancel: StorageClean.phase === "ask"
    confirmEnabled: StorageClean.phase !== "run"
    onConfirmed: {
        if (StorageClean.phase === "ask")
            StorageClean.start();
        else
            StorageClean.cancel();
    }
    onCancelled: StorageClean.cancel()

    ColumnLayout {
        visible: StorageClean.phase === "run" || StorageClean.phase === "done"
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MLinearProgress {
            visible: StorageClean.phase === "run"
            Layout.fillWidth: true
            indeterminate: true
        }
        MText {
            visible: StorageClean.phase === "run"
            value: StorageClean.step
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        MText {
            visible: StorageClean.phase === "done" && !StorageClean.error.length
            key: StorageClean.saved > 0
                ? "settings.storage.cleanSaved"
                : "settings.storage.cleanSavedNone"
            params: ({ n: Storage.formatBytes(StorageClean.saved) })
            styleName: "titleMedium"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        MText {
            visible: StorageClean.phase === "done" && StorageClean.error.length > 0
            key: "settings.storage.cleanFailed"
            styleName: "bodyMedium"
            color: Colors.color.error
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
