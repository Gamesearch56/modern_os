import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    spacing: Tokens.spacing.md

    MAvatar {
        Layout.alignment: Qt.AlignHCenter
        size: Tokens.spacing.xxl * 3
        source: User.faceUrl
    }
    MText {
        Layout.alignment: Qt.AlignHCenter
        value: User.displayName
        styleName: "titleLarge"
    }
    MHint {
        key: "settings.gated"
        Layout.fillWidth: true
    }
}
