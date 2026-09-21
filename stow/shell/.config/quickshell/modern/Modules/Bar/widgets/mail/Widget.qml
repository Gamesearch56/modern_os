import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

RowLayout {
    spacing: Tokens.spacing.xs

    MIconButton {
        tabFocus: false
        iconName: "mail-unread"
        key: "bar.mail"
        onClicked: {
            const e = Apps.entryFor("mail");
            const id = (e && (e.id || e.name)) || Apps.desktopId("mail");
            Hypr.raiseDesktopOrLaunch(String(id || ""), e);
        }
    }
}
