import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs

    MIconButton {
        iconName: "mail-unread"
        key: "bar.mail"
        onClicked: Mail.openMail()
    }
}
