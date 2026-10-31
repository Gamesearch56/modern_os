import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MOverlay {
    open: Update.open
    titleKey: "settings.systemUpdate"
    cardHeight: Tokens.spacing.xxl * 16
    closeVisible: !Update.running
    onClosed: Update.close()

    ColumnLayout {
        spacing: Tokens.spacing.md

        MText {
            value: Update.step
            styleName: "titleSmall"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        MLinearProgress {
            Layout.fillWidth: true
            indeterminate: Update.indeterminate
            value: Update.progress < 0 ? 0 : Update.progress
        }
        MLogView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: Update.log
        }
    }
}
